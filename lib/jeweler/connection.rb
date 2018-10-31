require 'faraday'

module Jeweler
  module Connection
    attr_reader :token, :host, :base_uri, :timeout

    def initialize(options = {})
      @host     = options[:host]
      @base_uri = options[:base_uri] || '/api/v1/'
      @token    = options[:token]
      @timeout  = options[:timeout] || 5
    end

    def perform_request(method, url, options = {})
      response = send_request(method, url, options)

      if response.success?
        if response.body.length > 0
          normalize_data(JSON.parse(response.body))
        else
          true
        end
      else
        case response.status
        when 400 then raise Jeweler::Errors::BadRequestError.new(JSON.parse(response.body))
        when 401 then raise Jeweler::Errors::UnauthorizedError.new(response.body)
        when 403 then raise Jeweler::Errors::ForbiddenError.new('')
        when 404 then raise Jeweler::Errors::ResourceNotFoundError.new("#{method}: #{url}")
        when 422 then raise Jeweler::Errors::ResourceInvalidError.new(JSON.parse(response.body))
        when 500..599
          raise Jeweler::Errors::RemoteServerError.new("Requesting: #{response.instance_variable_get(:@url).to_s}, received: #{response.body}")

        else
          raise Jeweler::Errors::OtherTransportError.new(response.body)
        end
      end
    end

private
    def send_request(method, url, options = {})
      connection = Faraday.new
      request_url = "#{@host}#{@base_uri}#{url}"

      return connection.send(method) do |request|
        set_headers(request)
        request.options.timeout = @timeout
        request.url(request_url)
        request.body = options[:payload] if options.has_key?(:payload)
      end
    end

    def set_params(request, params)
      params.each do |param, value|
        request.params[param.to_s] = value
      end
    end

    def set_headers(request)
      request.headers['Content-Type']  = 'application/json'
      request.headers['Accept']        = 'application/json'
      request.headers['Authorization'] = "Bearer #{@token}"
    end
  end
end
