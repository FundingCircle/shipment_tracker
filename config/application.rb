require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

Dotenv.load

module ShipmentTracker
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.action_dispatch.perform_deep_munge = false

    routes.default_url_options = { host: ENV['HOST_NAME'] || "localhost:#{ENV['PORT']}" }

    config.ssh_private_key = ENV['SSH_PRIVATE_KEY']
    config.ssh_public_key = ENV['SSH_PUBLIC_KEY']
    config.ssh_user = ENV['SSH_USER']
    config.approved_statuses = ENV.fetch('APPROVED_STATUSES', 'Ready for Deployment, Deployed, Done')
                                  .split(/\s*,\s*/)
    config.git_repository_cache_dir = Dir.tmpdir
    config.github_access_token = ENV['GITHUB_REPO_STATUS_ACCESS_TOKEN']
    config.data_maintenance_mode = ENV['DATA_MAINTENANCE'] == 'true'

    # default value needed for older events without locale
    config.default_deploy_locale = ENV.fetch('DEFAULT_DEPLOY_LOCALE', 'gb')

    # default value needed as not all heroku app names have the local as perfix
    config.default_heroku_deploy_locale = ENV.fetch('DEFAULT_HEROKU_DEPLOY_LOCALE', 'us')

    config.default_deploy_region = ENV.fetch('DEFAULT_DEPLOY_REGION', 'gb')

    # value is 'gb' and not 'uk' to comply with 'ISO 3166-1 alpha-2' codes
    config.deploy_regions = ENV.fetch('DEPLOY_REGIONS', 'gb,us').split(',')
  end
end
