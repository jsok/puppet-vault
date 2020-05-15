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

  newparam(:cert_name, namevar: true) do
    desc 'The name of the certificate'
  end

  newparam(:cert_dir) do
    desc 'The directory that the certificate lives in'
    validate do |value|
      path = Pathname.new(value)
      # Verify that an absolute path was given
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{value}"
      end
      # Verify that the given directory exists
      unless File.directory?(value)
        raise ArgumentError, "Directory not found for: #{value}"
      end
    end
  end

  newparam(:priv_key_name) do
    desc 'The name of the private key'
    defaultto do
      cert_name = @resource[:cert_name]
      extension = File.extname(cert_name)
      File.basename(cert_name, extension) + '.key'
    end
  end

  newparam(:priv_key_dir) do
    desc 'The directory that the private key lives in'
    defaultto do
      Pathname.new(@resource[:cert_dir])
    end
    validate do |value|
      path = Pathname.new(value)
      # Verify that an absolute path was given
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
      # Verify that the given directory exists
      unless File.directory?(value)
        raise ArgumentError, "Directory not found for: #{value}"
      end
    end
  end

  newparam(:new_cert_dir) do
    desc 'The path to save the new certificate in'
    # Default to the directory of the given cert
    defaultto do
      @resource[:cert_dir]
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

  newparam(:new_priv_key_dir) do
    desc 'The path to save the new certificate in'
    # Default to the directory of the given private key
    defaultto do
      @resource[:priv_key_dir]
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

  newparam(:owner) do
    desc 'Owner to assign for the new cert and key'
    defaultto('root')
  end

  newparam(:group) do
    desc 'Group to assign for the new cert and key'
    defaultto('root')
  end

  newparam(:common_name, namevar: true) do
    desc 'The common name to put in the certificate'
    defaultto do
      @resource[:cert_name]
    end
  end

  newparam(:alt_names) do
    desc 'Specifies requested Subject Alternative Names, in a comma-delimited list'
  end

  newparam(:ip_sans) do
    desc 'Specifies requested IP Subject Alternative Names, in a comma-delimited list'
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
