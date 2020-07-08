# for some reason, in functions you can't do normal requires because the module isn't in
# the load path, so you have to load it via absolute path :shrug:
# require 'puppet_x/encore/vault/client'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'encore', 'vault', 'client.rb'))

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
    required_param 'Vault::CertParams', :params
    return_type 'Hash'
  end

  def cert(params)
    # if serial_number parameter doesn't exist, try to find cert from facts based on
    # common_name, this should give us the serial number if we can find one
    # FYI serial number is used to query vault API for existing certificate information.
    # We can get everything except the private key if we just have the cert's serial number
    # Vault's API doesn't allow us to lookup via common name, so Serial Number is our unique
    # ID we use for querying.
    vault_existing_certs = Facter.value(:vault_existing_certs)
    if !params['serial_number'] && vault_existing_certs
      common_name = params['common_name']
      matching_certs = vault_existing_certs.select do |_path, cert_info|
        cert_info['common_name'] == common_name
      end

      params['serial_number'] = matching_certs.first['serial_number'] unless matching_certs.empty
    end
    get_or_create_cert(params)
  end

  def get_or_create_cert(params)
    cert_name      = params['cert_name']
    api_server     = params['api_server']
    api_token      = params['api_token']
    secret_role    = params['secret_role']
    serial_number  = params.fetch('serial_number',  nil)
    common_name    = params.fetch('common_name',    nil)
    alt_names      = params.fetch('alt_name',       nil)
    ip_sans        = params.fetch('ip_sans',        nil)
    api_port       = params.fetch('api_port',       8200)
    api_scheme     = params.fetch('api_scheme',     'https')
    cert_ttl       = params.fetch('cert_ttl',       '720h')
    regenerate_ttl = params.fetch('regenerate_ttl', 3)
    secret_engine  = params.fetch('secret_engine',  '/pki')
    client = PuppetX::Encore::Vault::Client.new(api_server: api_server,
                                                api_token: api_token,
                                                api_port: api_port,
                                                api_scheme: api_scheme,
                                                secret_engine: secret_engine)
    # if a serial number wasn't passed in, try to read it from facts about existing certs
    # on the system
    unless serial_number
      serial_number = find_serial_from_facts(params)
    end

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
      resp = client.create_cert(secret_role: secret_role, common_name: common_name,
                                ttl: cert_ttl, alt_names: alt_names, ip_sans: ip_sans)
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
