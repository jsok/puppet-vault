require 'pathname'
require 'time'
require 'rest-client'
require 'json'
# prepreqs
# - assume a certificate on the filesystem
#   - rick, help with an openssl to generate this for John
#   - potentially with a short expiration time, or one that is already
#     expired
#
# Steps
# - use Ruby OpenSSL if we can, otherwsie default to the `openssl` command
# - Convert this resource over to detect when a cert is going to expire
#   - put this in the exists? function
# - When the cert is going to expire, reach out to Vault and request a
#   new one.
#   - download the cert and put it on the filesystem
#   - probably need to write down the cert ID
# - Check the CRL or the cert itself
#
# References:
# - https://github.com/camptocamp/puppet-openssl/blob/master/lib/puppet/provider/x509_cert/openssl.rb
# - https://github.com/voxpupuli/puppet-grafana/blob/master/lib/puppet/provider/grafana_datasource/grafana.rb
# - https://github.com/voxpupuli/puppet-grafana/blob/master/lib/puppet/provider/grafana.rb
# - https://github.com/StackStorm/puppet-st2/blob/master/lib/puppet/provider/st2_pack/default.rb
# 
# Blog:
# - http://garylarizza.com/blog/2013/11/25/fun-with-providers/
# - http://garylarizza.com/blog/2013/11/26/fun-with-providers-part-2/
# - http://garylarizza.com/blog/2013/12/15/seriously-what-is-this-provider-doing/
#
Puppet::Type.type(:vault_cert).provide(:openssl) do

  desc 'Manages a certificates from HashiCorp Vault OpenSSL'

  commands openssl: 'openssl'

  #def self.check_private_key(resource)
  #  cert = OpenSSL::X509::Certificate.new(File.read(resource[:path]))
  #  priv = private_key(resource)
  #  cert.check_private_key(priv)
  #end

  def get_client_fqdn
    return @client_fqdn unless @client_fqdn.nil?
    @client_fqdn = Facter.value('fqdn')
  end

  def generate_cert
    common_name = get_client_fqdn
    url = 'http://' + resource[:vault_server] + ':' + resource[:vault_port] + '/v1/' + resource[:secret_engine] + '/issue/' + resource[:secret_role]

    headers = {
      "X-Vault-Token" => resource[:api_token]
    }

    payload = {
      name: resource[:secret_role],
      common_name: common_name,
      ttl: resource[:ttl_hours]
    }

    response = RestClient.post(url, payload.to_json, headers)

    response_body = JSON.parse(response.body)
    return response_body
  end

  def revoke_cert(serial_number)
    url = 'http://' + resource[:vault_server] + ':8200/v1/' + resource[:secret_engine] + '/revoke'

    headers = {
      "X-Vault-Token" => resource[:api_token]
    }

    payload = {
      serial_number: serial_number
    }

    response = RestClient.post(url, payload.to_json, headers)
    puts response

    if response.body
      return JSON.parse(response.body)
    else
      return response
    end
  end

  # Check whether the time left on the cert is less than the ttl
  def cert_expiring
    cert = get_certificate
    expire_date = cert.not_after

    now = Time.now
    # Calculate the difference in time (seconds) and convert to hours
    hours_until_expired = (expire_date - now) / 60 / 60
    Puppet.info("Time until expired: #{hours_until_expired.to_s}")

    if hours_until_expired < resource[:ttl_hours]
      true
    else
      false
    end
  end

  # Save an openssl cert object into the global cert var
  def get_certificate
    return @cert unless @cert.nil?
    @cert = if Pathname.new(resource[:cert_path]).exist?
              file = File.read(resource[:cert_path])
              OpenSSL::X509::Certificate.new(file)
            else
              false
            end
  end

  # Save an openssl PKey object into the global priv_key var
  def get_private_key
    return @priv_key unless @priv_key.nil?
    @priv_key = if Pathname.new(resource[:priv_key_path]).exist?
                  file = File.read(resource[:priv_key_path])
                  if resource[:auth_type] == 'dsa'
                    #OpenSSL::PKey::DSA.new(file, resource[:password])
                    OpenSSL::PKey::DSA.new(file)
                  elsif resource[:auth_type] == 'rsa'
                    #OpenSSL::PKey::RSA.new(file, resource[:password])
                    OpenSSL::PKey::RSA.new(file)
                  elsif resource[:auth_type] == 'ec'
                    #OpenSSL::PKey::EC.new(file, resource[:password])
                    OpenSSL::PKey::EC.new(file)
                  else
                     raise Puppet::Error,
                           "Unknown authentication type '#{resource[:auth_type]}'"
                  end
                  #OpenSSL::PKey::RSA.new(file)
                else
                  false
                end
  end

  def save_certificate
    common_name = get_client_fqdn
    cert = get_certificate
    priv_key = get_private_key
    # Save the new cert in the certs directory on the vault server
    cert_path = '/opt/vault/certs/' + common_name + '.crt'
    File.open(cert_path, 'w') do |f|
        f.write(cert)
    end

    # Save the new private key in the tls directory on the client
    key_path = '/etc/pki/tls/certs/' + common_name + '.pem'
    File.open(key_path, 'w') do |f|
      f.write(priv_key)
    end
  end

  def exists?
    # TODO
    #  - check for the certificate existing at all
    #  - check for the certificate being expired or not
    #    - if expired, returned false, so we create a new one
    #  - check if cert is revoked (if we want to get crazy)
    #    - if we have the cert ID, we can ask Vault for this
    cert = get_certificate
    priv_key = get_private_key
    if cert && priv_key
      if !cert.check_private_key(priv_key)
        return false
      end
      if cert_expiring
        return false
      end
      #unless self.class.old_cert_is_equal(resource)
      #  return false
      #end
      true
    else
      false
    end
  end

  def create
    # TODO
    #  - this is where we'll go to Vault and request a new cert
    #  - drop the cert on the filesystem
    # This is where we want to use the Grafana resource reference
    Puppet.info("CREATE")
    #cert = get_certificate
    save_certificate
  end

  def destroy
    # TODO
    #  - delete the cert off the filesystem
    #  - revoke the cert in Vault
    Puppet.info("DESTROY")
    #Pathname.new(resource[:cert_path]).delete
  end

end

