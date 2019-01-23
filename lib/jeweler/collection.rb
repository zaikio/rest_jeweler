module Jeweler
  class Collection
    include Enumerable
    include Finders
    include Writeable::Collection

    def initialize(client, retrieval_proc, resource_klass, owner = nil, prefetched_objects = nil)
      @client             = client
      @retrieval_proc     = retrieval_proc
      @resource_klass     = resource_klass
      @owner              = owner
      @prefetched_objects = prefetched_objects
      @retrieved          = prefetched_objects.is_a?(Array)
    end

    def find(id)
      unless id
        raise Jeweler::Errors::ResourceNotFoundError.new("unable to get #{@resource_klass} without ID")
      else
        @resource_klass.from_hash(
          @client,
          @client.perform_request(:get, "#{@resource_klass.path_for_show(@owner)}/#{id}"),
          @owner)
      end
    end

    def objects
      if @retrieved
        if @objects
          return @objects

        elsif @prefetched_objects
          return @objects = @prefetched_objects
        end

      else
        if @owner && !@owner.persisted?
          @objects = []
        else
          data = @retrieval_proc.call
          @retrieved = true
          @objects = (data || []).collect { |o| @resource_klass.from_hash(@client, o, @owner) }
        end
      end

      return @objects
    end

    def [](index)
      objects[index]
    end

    def size
      length
    end

    def length
      objects.length
    end

    def reload!
      # Don't try to reload collections from owners
      # that are not persisted yet
      return self unless @owner && @owner.persisted?

      @prefetched_objects = nil
      @retrieved = false
      @objects = objects
      self
    end

    def each(&block)
      objects.each { |item| yield item }
    end
  end
end
