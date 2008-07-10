module RTask
  module Gem
    def self.build(spec)
      ::Gem::Builder.new(spec).build
    end

    def self.gemspec(spec)
      spec.gemspec
    end
  end
end
