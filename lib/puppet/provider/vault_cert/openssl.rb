require 'pathname'
require 'time'
require 'net/https'
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

  # Return a Net::HTTP::Response object
  def send_request(operation = 'GET', path = '', data = nil, headers = {}, search_path = {})
    request = nil
    encoded_search = ''

    vault_scheme = resource[:api_scheme]
    vault_server = resource[:api_server]
    vault_port = resource[:api_port]

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
    uri = URI.parse '%s://%s:%d%s?%s' % [vault_scheme, vault_server, vault_port, path, encoded_search]

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

  def client_fqdn_get
    return @client_fqdn unless @client_fqdn.nil?
    @client_fqdn = Facter.value('fqdn')
  end

  def create_cert
    common_name = client_fqdn_get
    api_path = '/v1/' + resource[:secret_engine] + '/issue/' + resource[:secret_role]

    headers = {
      "X-Vault-Token" => resource[:api_token],
    }

    payload = {
      name: resource[:secret_role],
      common_name: common_name,
      ttl: resource[:cert_ttl],
    }

    response = send_request('POST', api_path, payload, headers)
    return JSON.parse(response.body) if response.body
    response
  end

  def revoke_cert
    serial_number = cert_serial_get

    api_path = '/v1/' + resource[:secret_engine] + '/revoke'

    headers = {
      "X-Vault-Token" => resource[:api_token],
    }

    payload = {
      serial_number: serial_number,
    }

    response = send_request('POST', api_path, payload, headers)
    if response.body
      return JSON.parse(response.body)
    else
      return response
    end
  end

  # Check whether the time left on the cert is less than the ttl
  # Return true if the cert is about to expire
  def check_cert_expiring
    cert = certificate_get
    expire_date = cert.not_after

    now = Time.now
    # Calculate the difference in time (seconds) and convert to hours
    hours_until_expired = (expire_date - now) / 60 / 60
    #Puppet.info("Time until expired: #{hours_until_expired.to_s}")

    if hours_until_expired < resource[:regenerate_ttl]
      true
    else
      false
    end
  end

  # Check whether the cert has been revoked
  # Return true if the cert is revoked
  def check_cert_revoked
    cert_serial = cert_serial_get
    api_path = '/v1/' + resource[:secret_engine] + '/cert/' + cert_serial

    headers = {
      "X-Vault-Token" => resource[:api_token]
    }

    response = send_request('GET', api_path, headers=headers)

    # Verify that a response was returned
    if response.body
      response_body = JSON.parse(response.body)
      # Check the revocation time on the cert object
      if response_body['data']['revocation_time'] > 0
        return true
      else
        return false
      end
    else
      return true
    end
  end

  # Save an openssl cert object into the global cert var
  def certificate_get
    return @cert unless @cert.nil?
    @cert = if Pathname.new(resource[:cert_path]).exist?
              file = File.read(resource[:cert_path])
              OpenSSL::X509::Certificate.new(file)
            else
              false
            end
  end

  # Save an openssl PKey object into the global priv_key var
  def private_key_get
    return @priv_key unless @priv_key.nil?
    @priv_key = if Pathname.new(resource[:priv_key_path]).exist?
                  file = File.read(resource[:priv_key_path])
                  auth_type = resource[:auth_type].downcase
                  if auth_type == 'dsa'
                    OpenSSL::PKey::DSA.new(file, resource[:key_password])
                    #OpenSSL::PKey::DSA.new(file)
                  elsif auth_type == 'rsa'
                    OpenSSL::PKey::RSA.new(file, resource[:key_password])
                    #OpenSSL::PKey::RSA.new(file)
                  elsif auth_type == 'ec'
                    OpenSSL::PKey::EC.new(file, resource[:key_password])
                    #OpenSSL::PKey::EC.new(file)
                  else
                     raise Puppet::Error,
                           "Unknown authentication type '#{auth_type}'"
                  end
                  #OpenSSL::PKey::RSA.new(file)
                else
                  false
                end
  end

  # Read the serial number from the certificate, convert it to base 16, and add colons
  def cert_serial_get
    cert = certificate_get
    # Get the serial number from the cert object
    serial_number = cert.serial.to_s(16)
    # Add a colon every 2 characters to the returned serial number
    serial_number.scan(/\w{2}/).join(':')
  end

  # Save the certificate and private key on the client server
  def client_cert_save(cert)
    # Name the certificate after the client FQDN
    cert_name = client_fqdn_get + '.crt'
    cert_dir = resource[:new_cert_path]
    # Save the new cert in the certs directory on the client server
    cert_path = File.join(cert_dir, cert_name)
    File.open(cert_path, 'w') do |f|
      f.write(cert['data']['certificate'])
    end

    # Name the private key after the client FQDN
    key_name = client_fqdn_get + '.key'
    key_dir = resource[:new_priv_key_path]
    # Save the new private key in the tls directory on the client
    key_path = File.join(key_dir, key_name)
    File.open(key_path, 'w') do |f|
      f.write(cert['data']['private_key'])
    end
  end

  def exists?
    cert = certificate_get
    priv_key = private_key_get
    # Check for the certificate existing at all
    if cert && priv_key
      # Check if the given private key matches the given cert
      if !cert.check_private_key(priv_key)
        Puppet.info("PRIVATE KEY FAILED")
        return false
      end
      # Check if the certificate is expired or not
      if check_cert_expiring
        Puppet.info("CERT EXPIRING")
        return false
      end
      # Check if the cert is revoked or not
      if check_cert_revoked
        Puppet.info("CERT REVOKED")
        return false
      end
      Puppet.info("CERT GOOD")
      true
    else
      Puppet.info("CERT OR KEY DOES NOT EXIST: #{resource[:cert_path]}")
      false
    end
  end

  # Create a new certificate with the vault API and save it on the filesystem
  def create
    Puppet.info("CREATE")
    # Revoke the old cert before creating a new one
    cert = certificate_get
    priv_key = private_key_get
    if cert && priv_key
      revoke_cert
    end
    new_cert = create_cert
    client_cert_save(new_cert)
  end

  def destroy
    Puppet.info("DESTROY")
    #  Revoke the cert in Vault
    revoke_cert
    #  Delete the cert and key off the filesystem
    Pathname.new(resource[:cert_path]).delete
    Pathname.new(resource[:priv_key_path]).delete
  end

end

