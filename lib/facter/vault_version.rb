#!/usr/bin/ruby
require 'facter'

vault_bin = Facter::Util::Resolution.exec("which vault")
if File.exists?("#{vault_bin}")
  version = Facter::Util::Resolution.exec("#{vault_bin} --version")
  Facter.add("vault_version") do
    setcode do
      version.match(/(?<=v)[0-9.]+/)[0]
    end
  end
end
