require 'faraday'

module Jeweler
  module Document

  private
    def retrieve_document(url)
      connection  = Faraday.new
      request_url = "#{@client.host}#{@client.base_uri}#{url}"

      response = connection.send(:get) do |request|
        request.headers['Accept']        = 'application/pdf'
        request.headers['Authorization'] = "Bearer #{@client.token}"

        request.options.timeout = @timeout
        request.url(request_url)
      end

      if response.success?
        file = Tempfile.new
        file.write response.body
        file.rewind

        return file
      else
        @client.send(:raise_errors, response, 'get', request_url)
      end
    end
  end
end
