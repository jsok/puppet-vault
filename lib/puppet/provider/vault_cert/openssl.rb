require 'pathname'
require 'time'
require 'net/https'
#require 'net/ssh'
#require 'net/scp'
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

  # Return a Net::HTTP::Response object
  def send_request(operation = 'GET', path = '', data = nil, headers = {}, search_path = {})
    request = nil
    encoded_search = ''

    vault_scheme = 'http'
    vault_server = resource[:vault_server]
    vault_port = resource[:vault_port]


    if URI.respond_to?(:encode_www_form)
      encoded_search = URI.encode_www_form(search_path)
    else
      # Ideally we would have use URI.encode_www_form but it isn't
      # available with Ruby 1.8.x that ships with CentOS 6.5.
      encoded_search = search_path.to_a.map do |x|
        x.map { |y| CGI.escape(y.to_s) }.join('=')
      end
      encoded_search = encoded_search.join('&')
    end
    uri = URI.parse format('%s://%s:%d%s?%s', vault_scheme, vault_server, vault_port, path, encoded_search)

    case operation.upcase
    when 'POST'
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = data.to_json
    when 'PUT'
      request = Net::HTTP::Put.new(uri.request_uri, headers)
      request.body = data.to_json
    when 'GET'
      request = Net::HTTP::Get.new(uri.request_uri, headers)
    when 'DELETE'
      request = Net::HTTP::Delete.new(uri.request_uri, headers)
    else
      raise Puppet::Error, format('Unsupported HTTP operation %s', operation)
    end

    request.content_type = 'application/json'
    #if resource[:grafana_user] && resource[:grafana_password]
    #  request.basic_auth resource[:grafana_user], resource[:grafana_password]
    #end
    resp = nil
    Net::HTTP.start(vault_server, vault_port,
                    use_ssl: vault_scheme == 'https',
                    verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      resp = http.request(request)
    end
    
    # check response for success, redirect or error
    case resp
    when Net::HTTPSuccess then
      resp
    when Net::HTTPRedirection then
      send_request(operation, resp['location'], data, headers)
    else
      message = 'code=' + resp.code
      message += ' message=' + resp.message
      message += ' body=' + resp.body
      raise resp.error_type.new(message, resp)
    end
  end  
    
  def get_client_fqdn
    Puppet.info(Facter.value('fqdn'))
    return @client_fqdn unless @client_fqdn.nil?
    @client_fqdn = Facter.value('fqdn')
  end

  def create_cert
    Puppet.info("create_cert")
    common_name = get_client_fqdn
    api_path = '/v1/' + resource[:secret_engine] + '/issue/' + resource[:secret_role]

    headers = {
      "X-Vault-Token" => resource[:api_token]
    }

    payload = {
      name: resource[:secret_role],
      common_name: common_name,
      ttl: resource[:ttl_hours]
    }

    response = send_request('POST', api_path, payload, headers)
    if response.body
      return JSON.parse(response.body)
    else
      return response
    end
  end

  def revoke_cert
    cert = get_certificate
    # Get the serial number from the cert object
    serial_number = cert.serial.to_s(16)
    # Add colons to the returned serial number
    serial_number = serial_number.scan(/\w{2}/).join(':')

    api_path = '/v1/' + resource[:secret_engine] + '/revoke'

    headers = {
      "X-Vault-Token" => resource[:api_token]
    }

    payload = {
      serial_number: serial_number
    }

    response = send_request('POST', api_path, payload, headers)
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

  def client_cert_save(cert)
    common_name = get_client_fqdn
    # Save the new cert in the certs directory on the client server
    cert_path = '/etc/pki/tls/certs/' + common_name + '.crt'
    File.open(cert_path, 'w') do |f|
      f.write(cert['data']['certificate'])
    end

    # Save the new private key in the tls directory on the client
    key_path = '/etc/pki/tls/private/' + common_name + '.pem'
    File.open(key_path, 'w') do |f|
      f.write(cert['data']['private_key'])
    end
  end

  def vault_cert_save(cert)
    common_name = get_client_fqdn
    # Save the new cert in the certs directory on the vault server
    cert_path = '/opt/vault/certs/' + common_name + '.crt'
    File.open(cert_path, 'w') do |f|
      f.write(cert['data']['certificate'])
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
    Puppet.info(cert.serial)
    priv_key = get_private_key
    if cert && priv_key
      if !cert.check_private_key(priv_key)
        Puppet.info("FALSE")
        return false
      end
      if cert_expiring
        Puppet.info("TRUE")
        return true
        #return false
      end
      #unless self.class.old_cert_is_equal(resource)
      #  return false
      #end
      Puppet.info("TRUE 2")
      true
    else
      Puppet.info("FALSE 2")
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
    #save_certificate
    new_cert = create_cert
    client_cert_save(new_cert)
    vault_cert_save(new_cert)
  end

  def destroy
    # TODO
    #  - delete the cert off the filesystem
    #  - revoke the cert in Vault
    Puppet.info("DESTROY")
    revoke_cert
    #Pathname.new(resource[:cert_path]).delete
  end

end

