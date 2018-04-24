require 'rest_jeweler/connection'
require 'rest_jeweler/writeable'
require 'rest_jeweler/resource'
require 'rest_jeweler/singleton_resource'
require 'rest_jeweler/finders'
require 'rest_jeweler/collection'
require 'rest_jeweler/errors'
require 'rest_jeweler/inflections'

module RestJeweler
  class Client
    include RestJeweler::Connection
  end
end
