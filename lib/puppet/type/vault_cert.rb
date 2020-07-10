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
    desc <<-EOS
      On Linux: the filename of the certificate without the directory.
      If this value doesn't contain an extension, then .crt will be appended  automatically.
      On Windows: the friendly name of the certificate.
    EOS
    munge do |value|
      return value if File.extname(value)
      value += '.crt' if Facter.value('kernel').casecmp?('linux')
      value
    end
  end

  newparam(:common_name) do
    desc <<-EOS
      The common name to put in the certificate.
      On Linux, defaults to basename(cert_name)
      On Windows, defaults to cert_name
    EOS
    defaultto do
      return @resource[:cert_name] unless Facter.value('kernel').casecmp?('linux')
      extension = File.extname(@resource[:cert_name])
      File.basename(@resource[:cert_name], extension)
    end
  end

  newparam(:alt_names) do
    desc 'Specifies requested Subject Alternative Names, in a comma-delimited list'
    validate do |value|
      unless value.is_a?(Array)
        raise ArgumentError, "alt_names is expected to be an Array, given: #{value.class.name}"
      end
      value.each do |v|
        unless v.is_a?(String)
          raise ArgumentError, "alt_names items are expected to be String, given: #{v.class.name}"
        end
      end
    end
  end

  newparam(:ip_sans) do
    desc 'Specifies requested IP Subject Alternative Names, in a comma-delimited list'
    validate do |value|
      unless value.is_a?(Array)
        raise ArgumentError, "ip_sans is expected to be an Array, given: #{value.class.name}"
      end
      value.each do |v|
        unless v.is_a?(String)
          raise ArgumentError, "ip_sans items are expected to be String, given: #{v.class.name}"
        end
      end
    end
  end

  newparam(:cert_dir) do
    desc 'The directory that the certificate lives in'

    defaultto do
      case Facter.value(:os)['family']
      when 'RedHat'
        '/etc/pki/tls/certs'
      when 'Debian'
        '/etc/ssl/certs'
      when 'windows'
        'Cert:\LocalMachine\My'
      else
        :absent
      end
    end

    validate do |value|
      kernel = Facter.value('kernel')
      if kernel.casecmp?('linux')
        path = Pathname.new(value)
        # Verify that an absolute path was given
        unless path.absolute?
          raise ArgumentError, "Path must be absolute: #{value}"
        end
        # Verify that the given directory exists
        unless File.directory?(value)
          raise ArgumentError, "Directory not found for: #{value}"
        end
      else
        unless value.start_with?('Cert:\\')
          raise ArgumentError, "Windows paths must start with Cert:\\ : #{value}"
        end
      end
    end
  end

  newparam(:cert_path) do
    desc 'A read-only state to return the full path to the certificate.'
    def retrieve
      File.join(@resource[:cert_dir], @resource[:cert_name])
    end

    validate do |_value|
      raise ArgumentError, 'cert_path is read-only'
    end
  end

  newparam(:cert) do
    desc <<-EOS
      Optional certificate data. If this is specified then it will be written to the file
      and Vault will not be contacted. This is only designed to be used on Windows systems.
      Usage of this parameter assumes that youre using the vault::cert() function to generate
      and refresh your certificates.
    EOS
  end

  newparam(:priv_key_name) do
    desc <<-EOS
      On Linux: the filename of the private key without the directory.
      If this value doesn't contain an extension, then .crt will be appended automatically.
      Default: '${basename(cert_name)}.key'.
      On Windows: unused.
    EOS
    defaultto do
      return @resource[:cert_name] unless Facter.value('kernel').casecmp?('linux')
      extension = File.extname(@resource[:cert_name])
      File.basename(@resource[:cert_name], extension) + '.key'
    end
    munge do |value|
      return value if File.extname(value)
      value += if Facter.value('kernel').casecmp?('linux')
                 '.key'
               end
      value
    end
  end

  newparam(:priv_key_dir) do
    desc 'The directory that the private key lives in'

    defaultto do
      case Facter.value(:os)['family']
      when 'RedHat'
        '/etc/pki/tls/private'
      when 'Debian'
        '/etc/ssl/private'
      when 'windows'
        'Cert:\LocalMachine\My'
      else
        :absent
      end
    end

    validate do |value|
      kernel = Facter.value('kernel')
      if kernel.casecmp?('linux')
        path = Pathname.new(value)
        # Verify that an absolute path was given
        unless path.absolute?
          raise ArgumentError, "Path must be absolute: #{path}"
        end
        # Verify that the given directory exists
        unless File.directory?(value)
          raise ArgumentError, "Directory not found for: #{value}"
        end
      else
        unless value.start_with?('Cert:\\')
          raise ArgumentError, "Windows paths must start with Cert:\\ : #{value}"
        end
      end
    end
  end

  newparam(:priv_key_path) do
    desc 'A read-only state to return the full path to the private key.'
    def retrieve
      File.join(@resource[:priv_key_dir], @resource[:priv_key_name])
    end

    validate do |_value|
      raise ArgumentError, 'priv_key_path is read-only'
    end
  end

  newparam(:priv_key_password) do
    desc 'The optional password for the private key'
  end

  newparam(:priv_key) do
    desc <<-EOS
      Optional private key data. If this is specified then it will be written to the file and
      Vault will not be contacted. This is only designed to be used on Windows systems. Usage
      of this parameter assumes that youre using the vault::cert() function to generate and
      refresh your certificates.
    EOS
  end

  newparam(:regenerate_ttl) do
    desc 'Re-generate and replace the certificate this many hours before it expires.'
    defaultto(3)
  end

  newparam(:cert_ttl) do
    desc 'TTL to give the new cert'
    defaultto('720h')
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
