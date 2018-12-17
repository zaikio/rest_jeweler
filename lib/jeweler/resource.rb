module Jeweler
  module Resource
    extend ActiveSupport::Concern

    attr_accessor :attributes, :parent

    included do
      extend Jeweler::Util
    end

    class_methods do
      cattr_reader :associations, :singleton_associations, :name_in_path,
        :name_in_params, :prefix, :prefix_overwrites_parent

      def from_hash(client, data, parent = nil)
        associations = self.instance_variable_get(:@associations)
        singleton_associations = self.instance_variable_get(:@singleton_associations)

        resource = self.new(client,
          data.except(*associations).except(*singleton_associations),
          parent)

        data.slice(*associations).each do |association, object_attributes|
          klass = const_in_current_namespace(association)

          resource.instance_variable_get(:@children)[association] = Collection.new(
            client,
            -> { client.perform_request(:get, klass.path_for_index(resource)) },
            klass,
            resource,
            object_attributes.collect { |oa| klass.from_hash(client, oa, resource) }
          )
        end

        data.slice(*singleton_associations).each do |association, attributes|
          next unless attributes
          klass = const_in_current_namespace(association)

          singleton = klass.from_hash(client, attributes, resource)
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
            @children[association] ||= Collection.new(@client, -> { @client.perform_request(:get, klass.path_for_index(self)) }, klass, self)
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
              klass = self.class.const_in_current_namespace(association)

              prototype = klass.new(@client, {}, self)
              prototype.extend(Jeweler::SingletonResource)

              object = klass.new(@client, @client.perform_request(:get, prototype.path_for_show), self)
              object.extend(Jeweler::SingletonResource)
              object

            rescue Errors::ResourceNotFoundError
              nil
            end
          end

          define_method "build_#{association}" do |attributes = {}|
            klass = self.class.const_in_current_namespace(association)
            object = klass.new(@client, attributes, self)
            object.extend(Jeweler::SingletonResource)

            instance_variable_get(:@children)[association.to_s] = object
          end

          define_method "create_#{association}" do |attributes = {}|
            object = self.send("build_#{association}", attributes)
            object.save

            return object
          end
        end
      end

      def name_in_path(name)
        @name_in_path = name
      end

      def name_in_params(name)
        @name_in_params = name
      end

      def path_prefix(prefix, options = {})
        @prefix = prefix
        @prefix_overwrites_parent = options.has_key?(:overwrite_parent_path) ? options[:overwrite_parent_path] : true
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
        prefix = self.class.instance_variable_get(:@prefix)
        prefix_overwrites_parent = self.class.instance_variable_get(:@prefix_overwrites_parent)

        if prefix
          if prefix_overwrites_parent
            segments << prefix
          elsif @parent.present?
            segments << @parent.path
          else
            segments << prefix
          end

        elsif @parent.present?
          segments << @parent.path
        end

        segments << self.name_in_path
        segments << self.id if self.persisted?
      end.join('/')
    end

    def name_in_path
      self.class.instance_variable_get(:@name_in_path) || self.class.to_s.demodulize.underscore.pluralize
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

    def reload!
      self.class.from_hash(@client, @client.perform_request(:get, self.path_for_show), @parent)
    end

    def inspect
      "##{self.class.to_s}:#{self.object_id}: #{self.id}"
    end
  end
end
