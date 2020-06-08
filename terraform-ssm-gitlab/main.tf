# Specify AWS provider and access details
provider "aws" {
  region    = "eu-west-1"
}

terraform {
  required_version = "= 0.12.25"
  required_providers {
    aws        = "2.63.0"
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc" {
  source                = "terraform-aws-modules/vpc/aws"
  version               = "2.38.0"

  name                  = "vpc"
  cidr                  = "192.168.80.0/20" #  HostMax:   192.168.95.254  // 4096 IP

  azs                   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets       = ["192.168.81.0/24", "192.168.82.0/24", "192.168.83.0/24"]
  public_subnets        = ["192.168.84.0/24", "192.168.85.0/24", "192.168.86.0/24"]

  enable_nat_gateway    = true
  single_nat_gateway    = true

  enable_dns_hostnames  = true
  enable_dns_support    = true

}

locals {
  public_nets   = module.vpc.public_subnets
  private_nets  = module.vpc.private_subnets
  external_name = "gitlab.example.com"
}

resource "aws_security_group" "allow_subnets_vpc" {
  name        = "gitlab_allow_subnets_vpc"
  description = "Allow any port form VPC CIDR"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [ module.vpc.vpc_cidr_block ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_public" {
  name        = "gitlab_allow_public"
  description = "Allow 443 80 22 ports for any IP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "gitlab" {
  ami                         = "ami-03d8261f577d71b6a" # ubuntu 18.04 ssm enabled
  instance_type               = "t3.large"
  subnet_id                   = local.private_nets.0
  availability_zone           = "eu-west-1a"
  monitoring                  = false
  hibernation                 = false
  disable_api_termination     = false
  vpc_security_group_ids      = [aws_security_group.allow_subnets_vpc.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.gitlab.id

  root_block_device {
    volume_size           = 100
    delete_on_termination = false
  }

  tags = {
    Name = "gitlab"
  }

  user_data = <<-EOF
                #!/bin/bash

                set -euxo pipefail

                echo "Starting provisioning..."

                EOF
}

resource "aws_db_subnet_group" "gitlab" {
  subnet_ids  = local.private_nets
}

resource "aws_db_instance" "gitlab" {
  name                      = "gitlab"
  allocated_storage         = 100
  storage_type              = "gp2"
  engine                    = "postgres"
  engine_version            = "11.7"
  instance_class            = "db.t3.small"
  username                  = "gitlab"
  password                  = "FODOADSErta2qz"
  db_subnet_group_name      = aws_db_subnet_group.gitlab.name
  skip_final_snapshot       = true
  final_snapshot_identifier = "gitlab"
  backup_retention_period   = 30
  backup_window             = "02:00-03:00"
  maintenance_window        = "sun:03:01-sun:05:00"

  vpc_security_group_ids = [aws_security_group.allow_subnets_vpc.id]
}

resource "aws_iam_instance_profile" "gitlab" {
  name = "iam-profile"
  role = aws_iam_role.gitlab.name
}

resource "aws_iam_role" "gitlab" {
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": [
            "ec2.amazonaws.com"
          ]
        }
      }
    ]
  }
EOF

}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.gitlab.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
  role       = aws_iam_role.gitlab.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_s3_bucket" "ansible-playbooks" {
  bucket = "ansible-1d3cd3f73a3d42730ae"
}

locals {
  content_gitlab_rb = templatefile("${path.module}/gitlab.rb",
  {
    db_host                   = aws_db_instance.gitlab.address
    external_name             = local.external_name
  })
  content_main_playbook = templatefile("${path.module}/main.yml",
  {
    ansible_bucket_id         = aws_s3_bucket.ansible-playbooks.id
  })
}

resource "aws_s3_bucket_object" "gitlab-rb" {
  bucket      = aws_s3_bucket.ansible-playbooks.id
  key         = "gitlab.rb"
  content     = local.content_gitlab_rb
  etag        = md5(local.content_gitlab_rb)
}

resource "aws_s3_bucket_object" "main-playbook" {
  bucket      = aws_s3_bucket.ansible-playbooks.id
  key         = "main.yml"
  content     = local.content_main_playbook
  etag        = md5(local.content_gitlab_rb)
}

resource "aws_ssm_document" "ssm-document" {
  name            = "ssm-document"
  document_type   = "Command"
  content         = templatefile("${path.module}/ssm-document.json",
  {
    bash_string = join("", [
      "apt-get update && apt-get install ansible awscli python-boto3 python3-botocore -y && ",
      "aws s3 cp s3://", aws_s3_bucket.ansible-playbooks.id, "/main.yml /root/main.yml && ",
      "echo 'localhost' > /root/inventory.txt && ",
      "export HOME='/root'; ansible-playbook --connection=local -i /root/inventory.txt /root/main.yml"
    ])
  })
}

resource "aws_ssm_association" "ssm-associatio" {
  name          = aws_ssm_document.ssm-document.name
  targets {
    key         = "InstanceIds"
    values      = [aws_instance.gitlab.id]
  }
}

resource "aws_elb" "gitlab-elb" {
  depends_on      = [aws_instance.gitlab]
  name            = "gitlab-pages-elb"
  internal        = false
  subnets         = [local.public_nets.0]
  security_groups = [aws_security_group.allow_public.id]

  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "arn:aws:acm:eu-west-1:687168902714:certificate/488daf76-104e-40fd-805e-6f6b8de2483e"
  }

  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    target              = "TCP:80"
    interval            = 30
  }

  instances                 = [aws_instance.gitlab.id]
  cross_zone_load_balancing = false

  tags = {
    Name = "gitlab-poc"
  }
}

resource "aws_route53_record" "gitlab-elb" {
  depends_on = [aws_instance.gitlab, aws_elb.gitlab-elb]
  zone_id    = "Z0124339HO06OVGOMD3X"
  name       = local.external_name
  type       = "CNAME"
  ttl        = "300"
  records    = [aws_elb.gitlab-elb.dns_name]
}
