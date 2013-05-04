module Houston
  module ErrorTracker
    module Adapter
      class ErrbitAdapter
        
        class << self
          
          def errors_with_parameters(project, app_id)
            return {errbit_app_id: ["cannot be blank"]} if app_id.blank?
            return {errbit_app_id: ["must be a hexadecimal number at least 24 characters long"]} unless app_id.to_s =~ /^[\da-f]{24,}$/
            
            # !todo: validate that the app exists
            # begin
            #   new_app(app_id).fetch!
            # rescue
            #   binding.pry
            # end
            
            {}
          end
          
          def build(project, app_id)
            return Houston::ErrorTracker::NullApp if app_id.blank?
            new_app(app_id)
          end
          
          def parameters
            [:errbit_app_id]
          end
          
          
          
          def connection
            @connection ||= self::Connection.new
          end
          
          delegate :problems_during, :notices_during, :to => :connection
          
        private
          
          def new_app(project_id)
            self::App.new(connection, project_id)
          end
          
        end
        
      end
    end
  end
end
