require "delegate"

class RTask
  class Spec < DelegateClass(::Gem::Specification)
    def initialize(gem_spec = ::Gem::Specification.new)
      super(gem_spec)
    end

    def attributes
      __getobj__.class.attribute_names
    end

    def bool_attributes
      [:has_rdoc]
    end

    def standard
      __getobj__.class.required_attributes +
        [:authors, :email, :homepage, :rubyforge_project, :description,
         :has_rdoc, :dependencies ] -
        [:rubygems_version, :specification_version, :date, :require_paths]
    end

    def required
      ::Gem::Specification.attribute_names.each do |name|
        ::Gem::Specification.required_attribute?()
      end
    end

    def array
      ::Gem::Specification.array_attributes
    end

    def type_of(name)
      if array.include?(name)
        return :array
      elsif bool.include?(name)
        return :bool
      else
        return :string
      end
    end

    alias :bool :bool_attributes
  end
end
