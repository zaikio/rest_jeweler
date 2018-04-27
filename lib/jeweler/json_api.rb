module Jeweler
  module JSONAPI
    def normalize_data(data)
      return data['data']
    end

    def interface_style
      :json_api
    end
  end
end
