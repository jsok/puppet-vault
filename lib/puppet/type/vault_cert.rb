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
      # Verify that an absolute path was given
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{value}"
      end
      # Verify that the given cert exists
      unless File.exist?(value)
        raise ArgumentError, "File not found for: #{value}"
      end
    end
  end

  newparam(:priv_key_path) do
    desc 'The path to the private key'
    defaultto do
      path = Pathname.new(@resource[:cert_path])
      "#{path.dirname}/#{path.basename(path.extname)}.key"
    end
    validate do |value|
      path = Pathname.new(value)
      # Verify that an absolute path was given
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
      # Verify that the given cert exists
      unless File.exist?(value)
        raise ArgumentError, "File not found for: #{value}"
      end
    end
  end

  newparam(:new_cert_path) do
    desc 'The path to save the new certificate in'
    # Default to the directory of the given cert
    defaultto do
      File.dirname(@resource[:cert_path])
    end
    validate do |value|
      path = Pathname.new(value)
      # Verify that an absolute path was given
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
      # Verify that the given directory exist
      unless File.directory?(value)
        raise ArgumentError, "Directory not found for: #{value}"
      end
    end
  end

  newparam(:new_priv_key_path) do
    desc 'The path to save the new certificate in'
    # Default to the directory of the given private key
    defaultto do
      File.dirname(@resource[:priv_key_path])
    end
    validate do |value|
      path = Pathname.new(value)
      # Verify that an absolute path was given
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
      # Verify that the given directory exist
      unless File.directory?(value)
        raise ArgumentError, "Directory not found for: #{value}"
      end
    end
  end

  newparam(:key_password) do
    desc 'The optional password for the private key'
  end

  newparam(:auth_type) do
    desc 'authentication type of the private key'
    defaultto('ec')
    validate do |value|
      acceptable_values = ['dsa', 'rsa', 'ec']
      unless acceptable_values.include? value.downcase
        raise ArgumentError, "auth_type must be one of: #{acceptable_values.join(', ')}"
      end
    end
  end

  newparam(:regenerate_ttl) do
    desc 'Re-generate and replace the certificate this many hours before it expires.'
    defaultto(3)
  end

  newparam(:cert_ttl) do
    desc 'TTL to give the new cert'
    defaultto('720h')
  end

  newparam(:sans) do
    desc 'IP Subject Alternative Names'
  end

  newparam(:api_server) do
    desc 'Hostname/IP Address of the Vault server'
  end

  newparam(:api_scheme) do
    desc 'Communication scheme/transport for the API ("http", "https")'
    defaultto('https')
  end

  newparam(:api_port) do
    desc 'Port for communicating with the Vault server'
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
