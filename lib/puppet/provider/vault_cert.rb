require 'puppet_x/encore/vault/client'

# Common provider for all vault_cert implementations
# This shares the code for communicating with the Vault API
class Puppet::Provider::VaultCert < Puppet::Provider
  ############################
  # helper methods

  def client
    @client ||= PuppetX::Vault::Client(api_server: resource[:api_server],
                                       api_token:  resource[:api_token],
                                       api_port: resource[:api_port],
                                       api_scheme: resource[:api_scheme],
                                       secret_engine: resource[:secret_engine])
    @client
  end

  def create_cert
    client.create_cert(secret_role: resource[:secret_role],
                       common_name: resource[:common_name],
                       ttl: resource[:cert_ttl],
                       alt_names: resource[:alt_names],
                       ip_sans: resource[:ip_sans])
  end

  def revoke_cert
    client.revoke_cert(serial_number: cert_serial_get)
  end

  def check_cert_revoked
    client.check_cert_revoked(serial_number: cert_serial_get)
  end
end
