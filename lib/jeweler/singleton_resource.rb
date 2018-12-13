module Jeweler
  module SingletonResource
    extend ActiveSupport::Concern

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
      end.join('/')
    end

    def name_in_path
      self.class.instance_variable_get(:@name_in_path) || self.class.to_s.demodulize.underscore
    end

    alias_method :path_for_show,    :path
    alias_method :path_for_create,  :path
    alias_method :path_for_update,  :path
    alias_method :path_for_destroy, :path
  end
end
