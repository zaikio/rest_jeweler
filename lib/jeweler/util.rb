module Jeweler
  module Util
    def const_in_current_namespace(class_name)
      # Search for class_name's class in same namespace as current class
      # Otherwise it's searched as top-level class/constant only
      [self.to_s.deconstantize, class_name.classify].reject(&:blank?).join('::').constantize

    # If we can't find anything, try again on top level
    rescue NameError
      [self.to_s.deconstantize.split('::').first, class_name.classify].join('::').constantize
    end
  end
end
