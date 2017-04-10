source "https://rubygems.org"

RUBY_2_OR_NEWER = RUBY_VERSION >= '2.0.0'

group :test do
  gem "rake", '~> 11'
  gem "puppet", ENV['PUPPET_GEM_VERSION'] || '~> 4.9'
  gem "rspec", '~> 3.5'
  gem "rspec-puppet"
  gem "puppetlabs_spec_helper"
  gem "metadata-json-lint"
  gem "rspec-puppet-facts"
  gem "json_pure"
  gem "parallel_tests", RUBY_2_OR_NEWER ? '~> 2' : '2.9.0'
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
