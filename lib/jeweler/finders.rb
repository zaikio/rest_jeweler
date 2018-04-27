module Jeweler
  module Finders
    def where(attributes)
      matching_objects = objects

      attributes.each_pair do |attribute, value|
        matching_objects.select! do |obj|
          begin
            obj.send(attribute) == value
          rescue NoMethodError
            raise Jeweler::Errors::UnknownAttributeError,
              "Attribute #{attribute} is not defined for #{obj.class}"
          end
        end
      end

      return matching_objects
    end

    def find_by(attributes)
      where(attributes).first
    end

    def find(id)
      if object = find_by(id: id)
        return object
      else
        raise Jeweler::Errors::RecordNotFound, "#{self.to_s} with ID #{id}"
      end
    end
  end
end
