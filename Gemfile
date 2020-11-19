source 'https://rubygems.org'

gem 'rails', '~> 5.0.0'

gem 'addressable', require: 'addressable/uri'
gem 'bootstrap-sass'
gem 'delayed_job_active_record'
gem 'delayed_job_web'
gem 'dotenv'
gem 'flag-icon-sass'
gem 'git_clone_url'
gem 'haml-rails'
gem 'has_secure_token'
gem 'honeybadger', '< 5'
gem 'jira-ruby', '~> 0.1.0', require: 'jira'
gem 'jquery-rails'
gem 'loga'
gem 'newrelic_rpm'
gem 'octokit', require: false
gem 'omniauth-auth0', '~> 1.4.0'
gem 'omniauth'
gem 'pg_failover'
gem 'pg_search'
gem 'pg', '~> 0.18.0'
gem 'raindrops'
gem 'prometheus_exporter', '< 0.6.0', require: false
gem 'pry-rails'
gem 'rugged', '~> 1.0.0'
gem 'sass-rails'
gem 'slack-notifier'
gem 'solid_use_case'
gem 'uglifier'
gem 'unicorn'
gem 'virtus'

group :dockerignore do
  gem 'therubyracer'
end

group :development do
  gem 'foreman', require: false
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'guard-rspec', require: false
  gem 'guard-cucumber', require: false
  gem 'mailcatcher'
end

group :development, :test do
  gem 'rspec-rails'
  gem 'rspec_junit_formatter'
  gem 'rubocop', '~> 0.65.0'
  gem 'pry-byebug'
end

group :production do
  gem 'rails_12factor'
end

group :test do
  gem 'capybara'
  gem 'cucumber-rails', '< 1.5', require: false
  gem 'database_cleaner'
  gem 'factory_bot'
  gem 'rack-test', require: 'rack/test'
  gem 'rails-controller-testing'
  gem 'shoulda-matchers', require: false
  gem 'simplecov', '< 0.18', require: false
  gem 'webmock', require: false
end
