module Houston
  module CIServer
    module Adapter
      class JenkinsAdapter
        
        def self.errors_with_parameters(project)
          {}
        end
        
        def self.build(project)
          Job.new(project)
        end
        
        def self.parameters
          []
        end
        
      end
    end
  end
end
