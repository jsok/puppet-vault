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

  newparam(:path, namevar: true) do
    desc 'The path to the certificate'
    validate do |value|
      path = Pathname.new(value)
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
    end
  end

  newparam(:private_key) do
    desc 'The path to the private key'
    defaultto do
      path = Pathname.new(@resource[:path])
      "#{path.dirname}/#{path.basename(path.extname)}.key"
    end
    validate do |value|
      path = Pathname.new(value)
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
    end
  end

  newparam(:ttl_hours) do
    desc 'Number of hours remaining before the cert needs to be renewed'
    defaultto(3)
  end

  newparam(:sans) do
    desc 'IP Subject Alternative Names'
  end

  newparam(:api_url) do
    desc 'URL of the Vault API'
  end

  newparam(:api_token) do
    desc 'API token used to authenticate with Vault'
  end

  newparam(:api_pki_path) do
    desc 'Path to the PKI secrets engine'
    defaultto('/int_ca')
  end

end
