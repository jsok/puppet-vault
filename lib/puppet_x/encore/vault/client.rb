require 'json'
require 'net/https'
require 'puppet_x'

# Encore module
module PuppetX::Encore; end

module PuppetX::Encore::Vault
  # Abstraction of the HashiCorp Vault API
  class Client
    def initialize(api_server:,
                   api_secret_role:,
                   api_port: 8200,
                   api_scheme: 'https',
                   api_secret_engine: '/pki',
                   api_auth_method: 'token',
                   api_auth_path: nil,
                   api_auth_token: nil,
                   api_auth_parameters: {},
                   ssl_verify: OpenSSL::SSL::VERIFY_NONE,
                   redirect_limit: 10,
                   headers: {})
      @api_server = api_server
      @api_port = api_port
      @api_scheme = api_scheme
      @api_secret_role = api_secret_role
      @api_secret_engine = api_secret_engine
      @api_auth_token = api_auth_token
      @api_auth_method = api_auth_method
      @api_auth_path = api_auth_path || "#{api_auth_method}/"
      @api_auth_parameters = api_auth_parameters
      @api_url = "#{@api_scheme}://#{@api_server}:#{@api_port}"
      @ssl_verify = ssl_verify
      @redirect_limit = redirect_limit

      # only need to auth if we dont have a token already
      authenticate unless @api_auth_token

      # add our auth token into the header, unless it was passed in,
      # then use the one from the passed in headers
      @headers = { 'X-Vault-Token' => @api_auth_token }.merge(headers)
    end

    def authenticate
      # default path + payload/parameters for most auth methods
      path = '/v1/auth/' + @api_auth_path + 'login'
      payload = @api_auth_parameters

      # make any modifications to the path or parameters that are unique to the auth method
      case @api_auth_method
      when 'ldap', 'okta', 'userpass'
        path += '/' + @api_auth_parameters['username']
      when 'oci'
        path += '/' + @api_auth_parameters['role']
      end
      response = post(path, body: payload, headers: {})
      @api_auth_token = response['auth']['client_token']
    end

    def create_cert(common_name:,
                    ttl:,
                    alt_names: nil,
                    ip_sans: nil)
      api_path = '/v1' + @api_secret_engine + '/issue/' + @api_secret_role
      payload = {
        name: @api_secret_role,
        common_name: common_name,
        ttl: ttl,
      }
      # Check if any Subject Alternative Names were given
      # Check if any IP Subject Alternative Names were given
      payload[:alt_names] = alt_names.join(',') if alt_names
      payload[:ip_sans] = ip_sans.join(',') if ip_sans

      post(api_path, body: payload)
    end

    def revoke_cert(serial_number)
      api_path = '/v1' + @api_secret_engine + '/revoke'
      payload = { serial_number: format_serial_number(serial_number) }
      post(api_path, body: payload)
    end

    def read_cert(serial_number)
      api_path = '/v1' + @api_secret_engine + '/cert/' + format_serial_number(serial_number)
      get(api_path)
    end

    # Check whether the cert has been revoked
    # Return true if the cert is revoked
    def check_cert_revoked(serial_number)
      response = read_cert(format_serial_number(serial_number))
      # Check the revocation time on the returned cert object
      response['data']['revocation_time'] > 0
    end

    def format_serial_number(serial_number)
      # unless serial number has the format XX:YY:ZZ
      # then reformat it by adding in colons every 2 characters
      unless serial_number =~ %r{(?:\w{2}:)+\w{2}}
        # Add a colon every 2 characters to the returned serial number
        serial_number = serial_number.scan(%r{\w{2}}).join(':')
      end
      serial_number
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

      puts headers
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
