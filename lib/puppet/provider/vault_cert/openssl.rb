require 'pathname'
require 'time'
require 'net/https'
require 'json'

# Steps
# - Verify that the given cert and private key exist and match
# - Check if the cert is revoked or expiring
# - When the cert is going to expire:
#   - Revoke the old cert with the Vault API
#   - Request a new cert with the Vault API
#   - Save the new cert in the given path on the filesystem

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
      raise Puppet::Error, 'Unsupported HTTP operation %s' % operation
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
      return JSON.parse(resp.body) if resp.body
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
    api_path = '/v1' + resource[:secret_engine] + '/issue/' + resource[:secret_role]

    headers = {
      'X-Vault-Token' => resource[:api_token],
    }

    payload = {
      name: resource[:secret_role],
      common_name: common_name,
      ttl: resource[:cert_ttl],
    }

    # Check if any Subject Alternative Names were given
    if resource[:alt_names]
      payload['alt_names'] = resource[:alt_names]
    end

    # Check if any IP Subject Alternative Names were given
    if resource[:ip_sans]
      payload['ip_sans'] = resource[:ip_sans]
    end

    send_request('POST', api_path, payload, headers)
  end

  def revoke_cert
    serial_number = cert_serial_get

    api_path = '/v1' + resource[:secret_engine] + '/revoke'

    headers = {
      'X-Vault-Token' => resource[:api_token],
    }

    payload = {
      serial_number: serial_number,
    }

    send_request('POST', api_path, payload, headers)
  end

  # Check whether the time left on the cert is less than the ttl
  # Return true if the cert is about to expire
  def check_cert_expiring
    cert = certificate_get
    expire_date = cert.not_after

    now = Time.now
    # Calculate the difference in time (seconds) and convert to hours
    hours_until_expired = (expire_date - now) / 60 / 60

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
    api_path = '/v1' + resource[:secret_engine] + '/cert/' + cert_serial

    headers = {
      'X-Vault-Token' => resource[:api_token],
    }

    response = send_request('GET', api_path, nil, headers)

    # Check the revocation time on the returned cert object
    if response['data']['revocation_time'] > 0
      true
    else
      false
    end
  end

  # Save an openssl cert object into the global cert var
  def certificate_get
    return @cert unless @cert.nil?
    cert_path = File.join(resource[:cert_dir], resource[:cert_name])
    @cert = if Pathname.new(cert_path).exist?
              file = File.read(cert_path)
              OpenSSL::X509::Certificate.new(file)
            else
              false
            end
  end

  # Save an openssl PKey object into the global priv_key var
  def private_key_get
    return @priv_key unless @priv_key.nil?
    priv_key_path = File.join(resource[:priv_key_dir], resource[:priv_key_name])
    @priv_key = if Pathname.new(priv_key_path).exist?
                  file = File.read(priv_key_path)
                  case resource[:auth_type].downcase
                  when 'dsa'
                    OpenSSL::PKey::DSA.new(file, resource[:key_password])
                  when 'rsa'
                    OpenSSL::PKey::RSA.new(file, resource[:key_password])
                  when 'ec'
                    OpenSSL::PKey::EC.new(file, resource[:key_password])
                  else
                    raise Puppet::Error, "Unknown authentication type '#{resource[:auth_type]}'"
                  end
                else
                  false
                end
  end

  # Read the serial number from the certificate, convert it to base 16, and add colons
  def cert_serial_get
    cert = certificate_get
    # Convert the base 10 serial number from the openssl cert to hexadecimal
    serial_number = cert.serial.to_s(16)
    # Add a colon every 2 characters to the returned serial number
    serial_number.scan(%r{\w{2}}).join(':')
  end

  # Save the certificate and private key on the client server
  def client_cert_save(cert)
    # Get the cert path from the directory and name
    cert_name = resource[:cert_name]
    cert_dir = resource[:new_cert_dir]
    # Save the new cert in the certs directory on the client server
    cert_path = File.join(cert_dir, cert_name)
    File.open(cert_path, 'w') do |f|
      f.write(cert['data']['certificate'])
    end

    # Get the private key path from the directory and name
    key_name = resource[:priv_key_name]
    key_dir = resource[:new_priv_key_dir]
    # Save the new private key in the tls directory on the client
    key_path = File.join(key_dir, key_name)
    File.open(key_path, 'w') do |f|
      f.write(cert['data']['private_key'])
    end

    # Change the owner and group of the newly created cert and key
    FileUtils.chown resource[:owner], resource[:group], [cert_path, key_path]
  end

  def exists?
    cert = certificate_get
    priv_key = private_key_get
    # Check for the certificate existing at all
    if cert && priv_key
      # Check if the given private key matches the given cert
      unless cert.check_private_key(priv_key)
        return false
      end
      # Check if the certificate is expired or not
      if check_cert_expiring
        return false
      end
      # Check if the cert is revoked or not
      if check_cert_revoked
        return false
      end
      true
    else
      false
    end
  end

  # Create a new certificate with the vault API and save it on the filesystem
  def create
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
    #  Revoke the cert in Vault
    revoke_cert
    #  Delete the cert and key off the filesystem
    cert_path = File.join(resource[:cert_dir], resource[:cert_name])
    Pathname.new(cert_path).delete
    priv_key_path = File.join(resource[:priv_key_dir], resource[:priv_key_name])
    Pathname.new(priv_key_path).delete
  end
end
