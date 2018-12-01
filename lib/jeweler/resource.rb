module Jeweler
  module Resource
    extend ActiveSupport::Concern

    attr_accessor :attributes, :parent

    included do
      extend Resource::ClassMethods
      extend Jeweler::Util
    end

    module ClassMethods
      cattr_reader :associations, :singleton_associations

      def from_hash(client, data, parent = nil)
        associations = self.instance_variable_get(:@associations)
        singleton_associations = self.instance_variable_get(:@singleton_associations)
        resource = self.new(client, data.except(associations), parent)

        data.slice(*associations).each do |association, objects|
          klass = const_in_current_namespace(association)

          resource.instance_variable_get(:@children)[association] = Collection.new(
            client,
            -> { @client.perform_request(:get, klass.path_for_index(self)) },
            klass,
            resource,
            objects
          )
        end

        data.slice(*singleton_associations).each do |association, attributes|
          next unless attributes
          klass = const_in_current_namespace(association)

          singleton = klass.new(client, attributes, resource)
          singleton.extend(Jeweler::SingletonResource)
          resource.instance_variable_get(:@children)[association] = singleton
        end

        return resource
      end

      def attributes(*attributes)
        (%i( id created_at updated_at ).concat(attributes)).each do |attribute|
          define_method attribute do
            @attributes[attribute.to_s]
          end
        end
      end

      def associations(*associations)
        @associations = associations.collect(&:to_s)

        @associations.each do |association|
          define_method association do
            klass = self.class.const_in_current_namespace(association)
            Collection.new(@client, -> { @client.perform_request(:get, klass.path_for_index(self)) }, klass, self)
          end
        end
      end

      # Singleton resources will have different accessors than
      # collection resources, since they return the resource
      # right away, whereas collection resources return a collection
      # proxy object with lazy loading
      def singleton_associations(*associations)
        @singleton_associations = associations.collect(&:to_s)

        @singleton_associations.each do |association|
          define_method association do
            @children[association.to_s] ||=
            begin
              prototype = klass.new(@client, {}, self)
              prototype.extend(Jeweler::SingletonResource)

              object = klass.new(@client, @client.perform_request(:get, prototype.path_for_show, self))
              object.extend(Jeweler::SingletonResource)
              object

            rescue Errors::ResourceNotFoundError
              nil
            end
          end
        end
      end

      def path_prefix(prefix = nil)
        if prefix
          @prefix = prefix.to_s
        else
          @prefix
        end
      end

      def path_for_index(parent = nil)
        self.new(nil, {}, parent).path_for_index
      end

      def path_for_show(parent = nil)
        self.new(nil, {}, parent).path_for_show
      end

      def path(parent = nil)
        self.new(nil, {}, parent).path
      end
    end

    def initialize(client, attributes = {}, parent = nil)
      @client = client
      @attributes = attributes.stringify_keys!
      @adhoc_writable_attributes = {}
      @parent = parent
      @children = {}
      @errors = []
    end

    def path
      Array.new.tap do |segments|
        segments << @parent.path if @parent && !self.class.path_prefix
        segments << self.class.path_prefix if self.class.path_prefix
        segments << self.name_in_path
        segments << self.id if self.persisted?
      end.join('/')
    end

    def name_in_path
      self.class.to_s.demodulize.underscore.pluralize
    end

    # Provides a possiblity for the given resource
    # to overwrite paths based on HTTP verb
    alias_method :path_for_index,   :path
    alias_method :path_for_show,    :path
    alias_method :path_for_create,  :path
    alias_method :path_for_update,  :path
    alias_method :path_for_destroy, :path

    # Only writeable resources cannot be persisted
    def persisted?
      true
    end

    # Only writable resources can be invalid
    def valid?
      true
    end
  end
end
