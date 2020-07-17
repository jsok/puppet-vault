# for some reason, in functions you can't do normal requires because the module isn't in
# the load path, so you have to load it via absolute path :shrug:
# require 'puppet_x/encore/vault/client'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'encore', 'vault', 'client'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'encore', 'vault', 'util'))

# Creates/renews a PKI certificate from Vault
#
# NOTE: Only use this on Windows, on Linux this function is NOT needed. See below for details.
#
# If a certificate is created/renewed it returns both its public key, private key,
# along with properties about the cert.
#
# If a certificate is NOT created/renewed, it returns just the public key
# along with properties about the cert. In this case the private key is NOT returned because
# Vault does NOT store the private keys, they are returned on certificate creation and
# then they are no longer accessible.
#
# The Vault API has some limitations in that it can only look up certificates by their
# "Serial Number" (run `openssl x509 -text -noout -in mycert.crt` and look for the
# Serial Number field). Due to this, we require the caller to pass in the serial number
# so we can lookup the cert. If the caller doesn't pass in the serial number, or it's undef
# or empty string, we assume that client doesn't have the certificate and a new one will
# be generated. To help with this, we've written some facts that return serial numbers
# and thumbprints of existing certificates on the system. See the `vault_existing_certs`
# fact for more details.
#
# Note, this is a total hack because Windows is wonky and needs the 'thumbprint'
# information for a certificate up front during the catalog compilation. Thumprints of
# certificates are unique and only exist once the certificate has been generated.
# Thus, only on windows, we need to run this function to generate the certificate,
# calculate its thumbprint and allow that to be used in the catalog for things like
# IIS bindings and WinRM bindings. This is a problem on windows because the "path"
# to a certificate in the cert store is something like: Cert:\LocalMachine\My\123456ABCDEF
# The last part of the certificate path is the thumbprint of the cert. Very inconvenient.
# Most of Microsoft's APIs for using certificates require you to pass in the Thumbprint/hash
# and likewise the puppet code for these resources requires the same thing.
# Now you, hopefully, see why we need to calculate these thumbprints up front and why
# this function exists.
#
# This is not a problem on Linux because certs are just regular file paths that we
# can specify. This makes it easy and things can "just work" no need to generate the cert
# to understand any properties about it so we can resolve the proper file path (thank god).
#
Puppet::Functions.create_function(:'vault::cert') do
  # @param TODO
  # @param serial_number Certificate serial number. Format: should be a string
  #   of hexadecimal numbers with a colon ':' every 2 characters (to separate the hex digits).
  #   You can get this by doing: openssl -text -noout -in mycert.crt
  # @return The cert TODO
  dispatch :cert do
    required_param 'Vault::CertParams', :params
    return_type 'Vault::CertReturn'
  end

  def find_cert_serial_number(params)
    # if serial_number parameter doesn't exist, try to find cert from facts based on
    # cert_name, this should give us the serial number if we can find one
    # FYI serial number is used to query vault API for existing certificate information.
    # We can get everything except the private key if we just have the cert's serial number
    # Vault's API doesn't allow us to lookup via common name, so Serial Number is our unique
    # ID we use for querying.
    serial_number = params['serial_number']
    unless serial_number
      Puppet.debug('serial number wasnt pass in, looking it up in facts')
      cert_name = params['cert_name']
      Puppet.debug("cert_name: #{cert_name}")
      # note: closure_scope is a special Puppet method for accessing the scope of the function
      # see: https://puppet.com/docs/puppet/latest/functions_ruby_implementation.html
      # It is only able to access global variables, like facts
      vault_existing_certs = closure_scope['facts']['vault_existing_certs']
      Puppet.debug("existing cert facts: #{vault_existing_certs.to_json}")
      if vault_existing_certs
        matching_certs = vault_existing_certs.select do |_path, cert|
          Puppet.debug("comparing #{cert['cert_name']} == #{cert_name} : #{cert['cert_name'] == cert_name}")
          cert['cert_name'] == cert_name
        end
        Puppet.debug("matching certs: #{matching_certs.to_json}")
        serial_number = matching_certs.values.first['serial_number'] unless matching_certs.empty?
        Puppet.debug("found existing serial number = #{serial_number}")
      else
        Puppet.debug("couldn't find existing cert facts")
      end
    end
    serial_number
  end

  def cert(params)
    cert_name         = params['cert_name']
    api_server        = params['api_server']
    api_secret_role   = params['api_secret_role']
    common_name       = params.fetch('common_name',       nil)
    alt_names         = params.fetch('alt_names',         nil)
    ip_sans           = params.fetch('ip_sans',           nil)
    api_auth_method     = params.fetch('api_auth_method', nil)
    api_auth_parameters = params.fetch('api_auth_parameters', nil)
    api_auth_path       = params.fetch('api_auth_path', nil)
    api_auth_token      = params.fetch('api_auth_token', nil)
    api_port          = params.fetch('api_port',          8200)
    api_scheme        = params.fetch('api_scheme',        'https')
    api_secret_engine = params.fetch('api_secret_engine', '/pki')
    cert_ttl          = params.fetch('cert_ttl',          '720h')
    regenerate_ttl    = params.fetch('regenerate_ttl',    3)
    serial_number     = find_cert_serial_number(params)
    client = PuppetX::Encore::Vault::Client.new(api_server: api_server,
                                                api_port: api_port,
                                                api_scheme: api_scheme,
                                                api_secret_engine: api_secret_engine,
                                                api_secret_role: api_secret_role,
                                                api_auth_method: api_auth_method,
                                                api_auth_path: api_auth_path,
                                                api_auth_token: api_auth_token,
                                                api_auth_parameters: api_auth_parameters)

    data = nil
    if serial_number
      Puppet.debug("using serial number = #{serial_number}")
      begin
        resp = client.read_cert(serial_number)
        data = resp['data']
        Puppet.debug("read in cert from vault = #{data.to_json}")
      rescue Net::HTTPNotFound, Net::HTTPServerException => e
        # HTTP 404 Not Found
        # if the cert doesn't exist by that serial number, then a 404 (Not Found)
        # error will be thrown, this means we need to create a new cert
        Puppet.debug("caught generic server exception with code: #{e.response.code}")
        Puppet.debug("caught generic server exception with code class: #{e.response.code.class.name}")
        unless e.response.code == '404'
          raise e
        end
        data = nil
      end
    end

    cert = nil
    priv_key = nil
    new_cert_needed = true
    if data
      Puppet.debug('checking existing cert to see if it needs refreshed')
      if data['revocation_time'] && data['revocation_time'] > 0
        # the cert is revoked, need a new one
        Puppet.debug("the cert is revoked, need a new one: #{data['revocation_time']}")
        new_cert_needed = true
      elsif data['certificate']
        # check if the cert is expired
        cert = data['certificate']
        x509_cert = OpenSSL::X509::Certificate.new(cert)
        # if cert is expiring, then we need a new cert
        new_cert_needed = PuppetX::Encore::Vault::Util.check_expiring(x509_cert.not_after,
                                                                      regenerate_ttl)
      end
    end

    if new_cert_needed
      Puppet.debug('new cert is needed, creating one')
      common_name ||= cert_name
      resp = client.create_cert(common_name: common_name, alt_names: alt_names,
                                ip_sans: ip_sans, ttl: cert_ttl)
      cert = resp['data']['certificate']
      priv_key = resp['data']['private_key']
    end

    thumbprint = nil
    cert_serial_number = nil
    if cert
      details = PuppetX::Encore::Vault::Util.cert_details(cert)
      thumbprint = details[:thumbprint]
      cert_serial_number = details[:serial_number]
      Puppet.debug("computed new cert serial: #{cert_serial_number}")
    end

    {
      'cert' => cert,
      'priv_key' => priv_key,
      'thumbprint' => thumbprint,
      'serial_number' => cert_serial_number,
    }
  end
end
