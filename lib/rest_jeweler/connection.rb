require 'faraday'

module RestJeweler
  module Connection
    attr_reader :token, :host, :base_uri

    def initialize(options = {})
      @host     = options[:host]
      @base_uri = '/api/v2/'
      @token    = options[:token]
    end

    def perform_request(method, url, options = {})
      connection = Faraday.new
      request_url = "#{@host}#{@base_uri}#{url}"
      response = connection.send(method) do |request|
        set_headers(request)
        request.url(request_url)
        request.body = options[:payload].to_json if options.has_key?(:payload)
      end

      if response.success?
        if response.body.length > 0
          JSON.parse(response.body)
        else
          true
        end
      else
        case response.status
        when 400 then raise RestJeweler::Errors::BadRequestError.new(JSON.parse(response.body))
        when 403 then raise RestJeweler::Errors::ForbiddenError.new('')
        when 404 then raise RestJeweler::Errors::ResourceNotFoundError.new(request_url)
        when 422 then raise RestJeweler::Errors::ResourceInvalidError.new(JSON.parse(response.body))
        when 500 then raise RestJeweler::Errors::RemoteServerError.new(response.body)
        end
      end
    end

private
    def set_params(request, params)
      params.each do |param, value|
        request.params[param.to_s] = value
      end
    end

    def set_headers(request)
      request.headers['Content-Type']  = 'application/json'
      request.headers['Authorization'] = "Bearer #{@token}"
    end
  end
end
