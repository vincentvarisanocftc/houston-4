Dir["#{Rails.root}/app/models/houston/ci/adapter/*_adapter.rb"].each(&method(:require_dependency))
require_dependency "houston/ci/errors"

module Houston
  
  # Classes in this namespace are assumed to implement
  # Houston's CI API.
  # 
  # At this time there are a Null adapter (None) and an adapter for use
  # with Unfuddle. Adapters for other ticket tracking systems can be added
  # here and will be automatically available to Houston projects.
  #
  module CI
    
    def self.adapters
      @adapters ||= 
        Adapter.constants
          .map { |sym| sym[/^.*(?=Adapter)/] }
          .sort_by { |name| name == "None" ? "" : name }
    end
    
    def self.adapter(name)
      Adapter.const_get(name + "Adapter")
    end
    
  end
end