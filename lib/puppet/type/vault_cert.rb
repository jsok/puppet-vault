require 'pathname'
# example:
# vault_cert { 'name/title':
#   cert_path           => '/path/to/cert.crt',
#   priv_key_path       => '/path/to/key.key',
#   ttl_hours_remaining => 3,
#   cert_ttl            => '720h',
#   sans                => 'cname.blah.domain.tld,127.0.0.1',
#   api_url             => 'https://vault.domain.tld:9100',
#   api_token           => 'xzy123',
#   secret_engine       => '/pki',
#   secret_role         => 'role_name',
# }
#

Puppet::Type.newtype(:vault_cert) do
  desc 'An certificate from HashiCorp Vault'

  ensurable

  newparam(:cert_path, namevar: true) do
    desc 'The path to the certificate'
    validate do |value|
      path = Pathname.new(value)
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
    end
  end

  newparam(:priv_key_path) do
    desc 'The path to the private key'
    validate do |value|
      path = Pathname.new(value)
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
    end
  end

  newparam(:password) do
    desc 'The optional password for the private key'
  end

  newparam(:auth_type) do
    desc 'authentication type of the private key'
    validate do |value|
      acceptable_values = ['dsa', 'rsa', 'ec']
      unless acceptable_values.include? value.downcase
        raise ArgumentError, "auth_type must be one of: #{acceptable_values.join(', ')}"
      end
    end
  end
  
  newparam(:ttl_hours_remaining) do
    desc 'Number of hours remaining before the cert needs to be renewed'
    defaultto(3)
  end

  newparam(:cert_ttl) do
    desc 'TTL to give the new cert'
    defaultto('720h')
  end

  newparam(:sans) do
    desc 'IP Subject Alternative Names'
  end

  newparam(:vault_server) do
    desc 'Hostname of the Vault server'
  end

  newparam(:vault_scheme) do
    desc 'Hostname of the Vault server'
    defaultto('http')
  end

  newparam(:vault_port) do
    desc 'Hostname of the Vault server'
    defaultto(8200)
  end

  newparam(:api_token) do
    desc 'API token used to authenticate with Vault'
  end

  newparam(:secret_engine) do
    desc 'Path to the PKI secrets engine'
    defaultto('/pki')
  end

  newparam(:secret_role) do
    desc 'Name of the role that the new cert belongs to'
  end

end
