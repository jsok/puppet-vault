require 'json'
require 'net/https'
require 'puppet_x'

# Encore module
module PuppetX::Encore; end

module PuppetX::Encore::Vault
  # Abstraction of the HashiCorp Vault API
  class Client
    def initialize(api_server:,
                   api_token:,
                   api_port: 8200,
                   api_scheme: 'https',
                   secret_engine: '/pki',
                   ssl_verify: OpenSSL::SSL::VERIFY_NONE,
                   redirect_limit: 10,
                   headers: {})
      @api_server = api_server
      @api_token = api_token
      @api_port = api_port
      @api_scheme = api_scheme
      @api_url = "#{@api_scheme}://#{@api_server}:#{@api_port}"
      @ssl_verify = ssl_verify
      @redirect_limit = redirect_limit
      @secret_engine = secret_engine
      # add our auth token into the header, unless it was passed in,
      # then use the one from the passed in headers
      @headers = { 'X-Vault-Token' => @api_token }.merge(headers)
    end

    def create_cert(secret_role:,
                    common_name:,
                    ttl:,
                    alt_names: nil,
                    ip_sans: nil)
      api_path = '/v1' + @secret_engine + '/issue/' + secret_role
      payload = {
        name: secret_role,
        common_name: common_name,
        ttl: ttl,
      }
      # Check if any Subject Alternative Names were given
      # Check if any IP Subject Alternative Names were given
      payload[:alt_names] = alt_names if alt_names
      payload[:ip_sans] = ip_sans if ip_sans

      post(api_path, body: payload)
    end

    def revoke_cert(serial_number)
      api_path = '/v1' + @secret_engine + '/revoke'
      payload = { serial_number: serial_number }
      post(api_path, body: payload)
    end

    def read_cert(serial_number)
      api_path = '/v1' + @secret_engine + '/cert/' + serial_number
      get(api_path)
    end

    # Check whether the cert has been revoked
    # Return true if the cert is revoked
    def check_cert_revoked(serial_number)
      response = read_cert(serial_number)
      # Check the revocation time on the returned cert object
      response['data']['revocation_time'] > 0
    end

    #################
    # HTTP helper methods

    # Return a Net::HTTP::Response object
    def execute(method,
                url,
                body: nil,
                headers: {},
                redirect_limit: @redirect_limit)
      raise ArgumentError, 'HTTP redirect too deep' if redirect_limit.zero?

      # setup our HTTP class
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = @ssl_verify

      # create our request
      request = net_http_request_class(method).new(uri)
      # copy headers into the request
      headers.each { |k, v| request[k] = v }
      # set body on the request
      if body
        request.content_type = 'application/json'
        request.body = body.to_json
      end

      # execute
      resp = http.request(request)

      # check response for success, redirect or error
      case resp
      when Net::HTTPSuccess then
        body = resp.body
        if body
          JSON.parse(body)
        else
          resp
        end
      when Net::HTTPRedirection then
        execute(method, resp['location'],
                body: body, headers: headers,
                redirect_limit: redirect_limit - 1)
      else
        message = 'code=' + resp.code
        message += ' message=' + resp.message
        message += ' body=' + resp.body
        raise resp.error_type.new(message, resp)
      end
    end

    def net_http_request_class(method)
      Net::HTTP.const_get(method.capitalize, false)
    end

    def get(path, body: nil, headers: @headers)
      url = "#{@api_url}#{path}"
      execute('get', url, body: body, headers: headers, redirect_limit: @redirect_limit)
    end

    def post(path, body: nil, headers: @headers)
      url = "#{@api_url}#{path}"
      execute('post', url, body: body, headers: headers, redirect_limit: @redirect_limit)
    end
  end
end
