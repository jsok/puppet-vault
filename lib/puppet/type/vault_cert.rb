require 'pathname'
# example:
# vault_cert { 'name/title':
#   path         => '/path/to/cert.crt',
#   private_key  => '/path/to/key.key',
#   # refresh if the cert is going to expire in the next 3 hours
#   ttl_hours    => 3,
#   sans         => 'cname.blah.domain.tld,127.0.0.1',
#   api_url      => 'https://vault.domain.tld:9100',
#   api_token    => 'xzy123',
#   api_pki_path => '/pki',
# }
#

Puppet::Type.newtype(:vault_cert) do
  desc 'An certificate from HashiCorp Vault'

  ensurable

  newparam(:cert_path, namevar: true) do
    desc 'The path to the certificate'
    #validate do |value|
    #  path = Pathname.new(value)
    #  unless path.absolute?
    #    raise ArgumentError, "Path must be absolute: #{path}"
    #  end
    #end
  end

  newparam(:priv_key_path) do
    desc 'The path to the private key'
    #defaultto do
    #  path = Pathname.new(@resource[:cert_path])
    #  "#{path.dirname}/#{path.basename(path.extname)}.key"
    #end
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
  end
  
  newparam(:ttl_hours_remaining) do
    desc 'Number of hours remaining before the cert needs to be renewed'
    defaultto(3)
  end

  newparam(:cert_ttl) do
    desc 'TTL to give the new cert'
    defaultto('30d')
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
    defaultto('/int_ca')
  end

  newparam(:secret_role) do
    desc 'Name of the role that the new cert belongs to'
  end

end
