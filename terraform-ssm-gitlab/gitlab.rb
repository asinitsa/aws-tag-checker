# put content into /etc/gitlab/gitlab.rb
# gitlab-ctl reconfigure
# Run this after installation

external_url "https://${external_name}"

gitlab_rails['db_adapter'] = "postgresql"
gitlab_rails['db_encoding'] = "unicode"
gitlab_rails['db_collation'] = nil
gitlab_rails['db_database'] = "gitlab"
gitlab_rails['db_pool'] = 1
gitlab_rails['db_username'] = "gitlab"
gitlab_rails['db_password'] = "FODOADSErta2qz"
gitlab_rails['db_host'] = "${db_host}"
gitlab_rails['db_port'] = 5432

nginx['enable'] = true
nginx['client_max_body_size'] = '250m'
nginx['redirect_http_to_https'] = false
nginx['listen_port'] = 80
nginx['listen_https'] = false

letsencrypt['enable'] = false

# configure app_id and app_secret here: https://console.developers.google.com/apis/credentials
gitlab_rails['omniauth_providers'] = [
    {
        :name => "google_oauth2",
        :app_id => "",
        :app_secret => "",
        :args => {:access_type => "offline", :approval_prompt => '' }
    }
]

gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['google_oauth2']
gitlab_rails['omniauth_sync_profile_from_provider'] = ['google_oauth2']
gitlab_rails['omniauth_block_auto_created_users'] = false

registry['enable'] = false

gitlab_rails['monitoring_whitelist'] = ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']