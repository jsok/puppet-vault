source ENV['GEM_SOURCE'] || "https://rubygems.org"

group :test do
  gem 'puppetlabs_spec_helper', '~> 2.15.0',                         :require => false
  gem 'rspec-puppet', '~> 2.5',                                     :require => false
  gem 'rspec-puppet-facts',                                         :require => false
  gem 'rspec-puppet-utils',                                         :require => false
  gem 'rspec-json_expectations',                                    :require => false
  gem 'puppet-lint-leading_zero-check',                             :require => false
  gem 'puppet-lint-trailing_comma-check',                           :require => false
  gem 'puppet-lint-version_comparison-check',                       :require => false
  gem 'puppet-lint-classes_and_types_beginning_with_digits-check',  :require => false
  gem 'puppet-lint-unquoted_string-check',                          :require => false
  gem 'puppet-lint-variable_contains_upcase',                       :require => false
  gem 'semantic_puppet',                                            :require => false
  gem 'metadata-json-lint',                                         :require => false
  gem 'redcarpet',                                                  :require => false
  gem 'rubocop', '~> 0.51',                                         :require => false
  gem 'rubocop-rspec', '~> 1.20',                                   :require => false
  gem 'mocha', '>= 1.2.1',                                          :require => false
  gem 'coveralls',                                                  :require => false
  gem 'simplecov-console',                                          :require => false
  gem 'parallel_tests',                                             :require => false
  gem 'fakefs',                                                     :require => false
end

group :development do
  gem 'puppet-blacksmith'
  gem 'travis'
end

group :system_tests do
  gem "beaker", '~> 4',               :require => false
  gem 'beaker-puppet', '~>1.0',       :require => false
  gem "beaker-docker",                :require => false
  gem "beaker-rspec",                 :require => false
  gem 'beaker-puppet_install_helper', :require => false
  gem 'beaker-module_install_helper', :require => false
end

ENV['PUPPET_GEM_VERSION'].nil? ? puppetversion = '~> 6' : puppetversion = ENV['PUPPET_GEM_VERSION'].to_s
gem 'puppet', puppetversion, :require => false, :groups => [:test]

# vim: syntax=ruby
