source ENV['GEM_SOURCE'] || "https://rubygems.org"

group :test do
  gem 'puppetlabs_spec_helper', '~> 2.5.0',                         :require => false
  gem 'rspec-puppet', '~> 2.5',                                     :require => false
  gem 'rspec-puppet-facts',                                         :require => false
  gem 'rspec-puppet-utils',                                         :require => false
  gem 'puppet-lint-leading_zero-check',                             :require => false
  gem 'puppet-lint-trailing_comma-check',                           :require => false
  gem 'puppet-lint-version_comparison-check',                       :require => false
  gem 'puppet-lint-classes_and_types_beginning_with_digits-check',  :require => false
  gem 'puppet-lint-unquoted_string-check',                          :require => false
  gem 'puppet-lint-variable_contains_upcase',                       :require => false
  gem 'metadata-json-lint',                                         :require => false
  gem 'redcarpet',                                                  :require => false
  gem 'rubocop', '~> 0.51',                                         :require => false
  gem 'rubocop-rspec', '~> 1.20',                                   :require => false
  gem 'mocha', '>= 1.2.1',                                          :require => false
  gem 'coveralls',                                                  :require => false
  gem 'simplecov-console',                                          :require => false
  gem 'rack', '~> 1.0',                                             :require => false if RUBY_VERSION < '2.2.2'
  gem 'parallel_tests',                                             :require => false
  gem 'fakefs',                                                     :require => false
end

group :development do
  gem 'puppet-blacksmith'
  gem 'travis'
end

group :system_tests do
  gem "beaker", '~> 3',               :require => false
  gem "beaker-rspec", '~> 6',         :require => false
  gem 'beaker-puppet_install_helper', :require => false
  gem 'beaker-module_install_helper', :require => false
end

ENV['PUPPET_GEM_VERSION'].nil? ? puppetversion = '~> 5' : puppetversion = ENV['PUPPET_GEM_VERSION'].to_s
gem 'puppet', puppetversion, :require => false, :groups => [:test]

# vim: syntax=ruby
