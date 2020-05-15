require 'net/https'
require 'json'

# Common provider for all vault_cert implementations
# This shares the code for communicating with the Vault API
class Puppet::Provider::VaultCert < Puppet::Provider
  ############################
  # helper methods

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

  def create_cert
    api_path = '/v1' + resource[:secret_engine] + '/issue/' + resource[:secret_role]

    headers = {
      'X-Vault-Token' => resource[:api_token],
    }

    payload = {
      name: resource[:secret_role],
      common_name: resource[:common_name],
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
end
