require 'puppet_x/encore/vault/client'

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
  # @param serial_number Certificate serial number. Format: should be a string of hexadecimal numbers with a colon ':' every 2 characters (to separate the hex digits). You can get this by doing: openssl -text -noout -in mycert.crt
  #
  # @return The cert TODO
  dispatch :cert do
    required_param 'String',  :cert_name
    required_param 'String',  :api_server
    required_param 'Integer', :api_token
    required_param 'String',  :secret_role
    required_param 'String',  :serial_number
    optional_param 'Integer', :regenerate_ttl
    optional_param 'String',  :cert_ttl
    optional_param 'String',  :common_name
    optional_param 'String',  :alt_names
    optional_param 'String',  :ip_sans
    optional_param 'String',  :api_scheme
    optional_param 'Integer', :api_port
    optional_param 'String',  :secret_engine
    return_type 'Hash'
  end

  def cert(cert_name,
           api_server,
           api_token,
           secret_role,
           serial_number  = nil,
           common_name    = nil,
           alt_names      = nil,
           ip_sans        = nil,
           api_port       = 8200,
           api_scheme     = 'https',
           cert_ttl       = '720h',
           regenerate_ttl = 3,
           secret_engine  = '/pki')
    client = PuppetX::Vault::Client(api_server: api_server,
                                    api_token:  api_token,
                                    api_port: api_port,
                                    api_scheme: api_scheme,
                                    secret_engine: secret_engine)
    data = nil
    if serial_number
      begin
        resp = client.read_cert(serial_number)
        data = resp['data']
      rescue Net::HTTPError
        # if the cert doesn't exist by that serial number, then a 403 error will be thrown
        # this means we need to create a new cert
        data = nil
      end
    end

    cert = nil
    priv_key = nil
    new_cert_needed = true
    if data
      if data['revocation_time'] && data['revocation_time'] > 0
        # the cert is revoked, need a new one
        new_cert_needed = true
      elsif data['certificate']
        # check if the cert is expired
        cert = data['certificate']
        x509_cert = OpenSSL::X509::Certificate.new(cert)
        # TODO: move this common code from openssl and powershell into client
        expire_date = x509_cert.not_after
        now = Time.now
        # Calculate the difference in time (seconds) and convert to hours
        hours_until_expired = (expire_date - now) / 60 / 60
        new_cert_needed = (hours_until_expired < regenerate_ttl)
      else
        new_cert_needed = false
      end
    end

    if new_cert_needed
      # set common name to cert_name if common_name was not passed in
      common_name ||= cert_name
      resp = client.create_cert(secret_role, common_name, cert_ttl,
                                alt_names: alt_names, ip_sans: ip_sans)
      cert = resp['data']['certificate']
      priv_key = resp['data']['private_key']
    end

    thumbprint = nil
    cert_serial_number = nil
    if cert
      x509_cert = OpenSSL::X509::Certificate.new(cert)
      thumbprint = OpenSSL::Digest::SHA1.new(x509_cert.to_der).to_s.upcase
      cert_serial_number = x509_cert.serial.to_s(16)
    end

    {
      cert: cert,
      priv_key: priv_key,
      thumbprint: thumbprint,
      serial_number: cert_serial_number,
    }
  end
end
