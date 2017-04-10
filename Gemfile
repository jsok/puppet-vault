source "https://rubygems.org"

group :test do
  gem "rake", '~> 11'
  gem "puppet", ENV['PUPPET_GEM_VERSION'] || '~> 4.9'
  gem "rspec", '~> 3.5'
  gem "rspec-puppet"
  gem "puppetlabs_spec_helper"
  gem "metadata-json-lint"
  gem "rspec-puppet-facts"
  gem "json_pure", '<= 2.0.1', :require => false if RUBY_VERSION < '2.0.0'
end

group :development do
  gem "travis"
  gem "travis-lint"
  gem "vagrant-wrapper"
  gem "puppet-blacksmith"
  gem "guard-rake"
end

group :system_tests do
  gem "beaker"
  gem "beaker-rspec"
end
