# for some reason, in functions you can't do normal requires because the module isn't in
# the load path, so you have to load it via absolute path :shrug:
# require 'puppet_x/encore/vault/client'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'encore', 'vault', 'util'))

# Computes a X509 SSL/TLS certificate details including:
#  - thumbprint
#  - serial number
#  - common name
#  - subject
#  - not after date
#  - not before date
Puppet::Functions.create_function(:'vault::cert_details') do
  # @param cert A Base64 encoded certificate string (pem, crt, etc)
  # @return A hash containing details about the certificate
  dispatch :cert do
    required_param 'String', :cert
    return_type 'Vault::CertDetails'
  end

  def cert(cert)
    details = PuppetX::Encore::Vault::Util.cert_details(cert)
    # convert keys from symbols to strings
    details.map { |k, v| [k.to_s, v] }.to_h
  end
end
