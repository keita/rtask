require "rubygems/specification"

class RTask
  module Gem
    def self.build(spec)
      ::Gem::Builder.new(spec).build
    end

    def self.gemspec(spec)
      spec.gemspec
    end
  end
end

# for showing gem specs
module Gem
  class Dependency
    def to_s
      @name.to_s
    end
  end
end
