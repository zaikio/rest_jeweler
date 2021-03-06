module Jeweler
  module Writeable
    module Collection
      def create(attributes = {})
        self.build(attributes).tap do |object|
          object.save
        end
      end

      def create!(attributes = {})
        self.build(attributes).tap do |object|
          object.save!
        end
      end

      def build(attributes = {})
        @resource_klass.new(@client, attributes, @owner).tap do |new_object|
          self.objects << new_object
        end
      end
    end

    module Resource
      extend ActiveSupport::Concern

      included do
        extend Writeable::Resource::ClassMethods
      end

      attr_accessor :adhoc_writable_attributes
      attr_reader :errors

      module ClassMethods
        def writeable_attributes(*attributes)
          attributes.each do |attribute|
            define_method "#{attribute}=" do |value|
              @attributes[attribute.to_s] = value
            end
          end
        end
      end

      def save
        raise Jeweler::Errors::ParentNotPersistedError, 'you can\'t save a child object unless its parent has been saved' if self.parent && !self.parent.persisted?
        self.persisted? ? self.update : self.create
      end

      def create
        perform_request do
          self.attributes = @client.perform_request(:post, self.path_for_create, payload: attributes_for_write)
        end
      end

      def update(attributes = {})
        self.attributes = attributes

        perform_request do
          # PUT requests usually return 204 No Content, so don't assign the response to attributes
          @client.perform_request(:put, self.path_for_update, payload: attributes_for_write)
        end
      end

      def save!
        raise Jeweler::Errors::ParentNotPersistedError, 'you can\'t save a child object unless its parent has been saved' if self.parent && !self.parent.persisted?
        self.persisted? ? self.update! : self.create!
      end

      def create!
        unless self.create
          raise Jeweler::Errors::ResourceInvalidError, @errors.inspect
        end
      end

      def update!(attributes = {})
        unless self.update(attributes)
          raise Jeweler::Errors::ResourceInvalidError, @errors.inspect
        end
      end

      def destroy
        perform_request do
          @client.perform_request(:delete, self.path_for_destroy)
          attributes['id'] = nil
        end
      end

      def attributes=(attributes)
        @attributes.merge!(attributes.stringify_keys!)
      end

      def persisted?
        self.id.present?
      end

      def new_record?
        !persisted?
      end

      def valid?
        @errors.empty?
      end

      def writeable_attributes
        @attributes.slice(*self.class.instance_methods.grep(/[a-z]+=/).collect { |a| a.to_s[0..-2] }).merge(@adhoc_writable_attributes)
      end

      def name_in_params
        self.class.instance_variable_get(:@name_in_params) || self.class.to_s.demodulize.underscore
      end

    private
      def perform_request(&block)
        block.call
        clear_errors
        return true

      rescue Jeweler::Errors::BadRequestError => e
        @errors = e.missing_parameters.nil? ? e.raw_payload : e.missing_parameters
        return false
      rescue Jeweler::Errors::ResourceInvalidError => e
        @errors = e.validation_errors
        return false
      end

      def clear_errors
        @errors = []
      end

      def attributes_for_write
        # Consider all attribute= functions as writable
        # attributes that need to be send over the wire
        case @client.interface_style
        when :json_api then self.writeable_attributes
        when :rails    then JSON.generate({ self.name_in_params => self.writeable_attributes })
        end
      end
    end
  end
end
