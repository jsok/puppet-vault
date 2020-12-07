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
      On Windows: the friendly name of the certificate. Windows uses this as the unique
      property, so only one certificate should have this friendly name (since it's our title
      in Puppet)
    EOS
    munge do |value|
      extname = File.extname(value)
      return value if extname && !extname.empty?
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
      extname = File.extname(value)
      return value if extname && !extname.empty?
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

  newparam(:api_secret_engine) do
    desc 'Path to the PKI secrets engine'
    defaultto('/pki')
  end

  newparam(:api_secret_role) do
    desc 'Name of the role that the new cert belongs to'
  end

  newparam(:api_auth_method) do
    desc <<-EOS
      Authentication method to use when communicating with the Vault API, see
      https://www.vaultproject.io/api-docs/auth
      Currently all auth methods are supported. The auth method name is the name
      in the API docs in the /auth/<method> URL.
      If your auth method is mounted to a different path you can change this with
      api_auth_path.
      All auth methods, except 'token', require you to pass in api_auth_parameters.
      For the 'token' auth method please specify api_auth_token.
    EOS
    defaultto('token')
  end

  newparam(:api_auth_path) do
    desc <<-EOS
      If you have mounted your auth backend to a different path, specify this here.
      Please include a trailing '/' in this path.
      The URL for the authentication endpoint is: /v1/auth/<path>login
    EOS
    defaultto do
      return @resource[:api_auth_method] + '/'
    end
    munge do |value|
      value += '/' unless value[-1] == '/'
      value
    end
  end

  newparam(:api_auth_token) do
    desc 'If using the "token" api_auth_method, this should be the Vault API auth token'
  end

  newparam(:api_auth_parameters) do
    desc <<-EOS
      Hash of parameters to use when performing the login operation using the auth method
      on the Vault API.
      These can be determined by looking at the Vault API docs for the /v1/auth/<method>/login
      API call. Parameters in those tables should be specified. These will be included in the
      body of the API request.
      Note: some auth methods suck as 'ldap', 'okta', 'oci' and 'userpass' utilize a
      'username' or 'role' parameter that is actually part of the URL. Don't worry, we handl
      that correctly, simply pass those parameters in this hash and we'll put them in the URL
      for you
    EOS
    validate do |value|
      unless value.is_a?(Hash)
        raise ArgumentError, "api_auth_parameters is expected to be a Hash, given: #{value.class.name}"
      end
    end
  end
end
