module Houston
  module Adapters
    module TicketTracker
      class UnfuddleAdapter
        class Ticket
          
          
          
          def initialize(connection, attributes)
            @connection       = connection
            @raw_attributes   = attributes
            @severity         = get_severity_name(attributes["severity_id"])
            
            # required
            @remote_id        = attributes["id"]
            @number           = attributes["number"]
            @summary          = attributes["summary"]
            @description      = attributes["description"]
            @type             = get_type
            @closed_at        = attributes["closed_on"] && Time.parse(attributes["closed_on"])
            
            # optional
            @tags             = get_tags
            @antecedents      = get_antecedents
            @deployment       = get_custom_value(Houston::TMI::NAME_OF_DEPLOYMENT_FIELD)
            @prerequisites    = parse_prerequisites(attributes["associations"])
            @due_date         = attributes["due_on"]
          end
          
          attr_reader :raw_attributes,
                      
                      :remote_id,
                      :number,
                      :summary,
                      :description,
                      :type,
                      :closed_at,
                      
                      :tags,
                      :antecedents,
                      :deployment,
                      :prerequisites,
                      :severity,
                      :due_date
          
          def attributes
            { remote_id:      remote_id,
              number:         number,
              summary:        summary,
              description:    description,
              type:           type,
              closed_at:      closed_at,
              
              tags:           tags,
              antecedents:    antecedents,
              deployment:     deployment,
              prerequisites:  prerequisites,
              due_date:       due_date }
          end
          
          
          
          def resolve!
            unless %w{resolved closed}.member? @raw_attributes["status"]
              ticket = unfuddle.ticket(remote_id)
              ticket.update_attributes!("status" => "resolved", "resolution" => "fixed")
            end
          end
          
          
          
          def close!
            ticket = unfuddle.ticket(remote_id)
            ticket.update_attributes!("status" => "closed")
          end
          
          
          
          # !todo: refactor this method to be more generic and abstract
          def update_attribute(attribute, value)
            case attribute
            when :deployment
              attribute = unfuddle.get_ticket_attribute_for_custom_value_named!(Houston::TMI::NAME_OF_DEPLOYMENT_FIELD) # e.g. field2_value_id
              id = unfuddle.find_custom_field_value_by_value!(Houston::TMI::NAME_OF_DEPLOYMENT_FIELD, value).id
              
              ticket = unfuddle.ticket(remote_id)
              ticket.update_attributes!(attribute => id)
              
            else
              raise NotImplementedError
            end
          end
          
          
          
          def get_custom_value(custom_field_name)
            unfuddle_ticket = @raw_attributes
            
            retried_once = false
            begin
              custom_field_key = custom_field_name.underscore.gsub(/\s/, "_")
              
              key = find_in_cache_or_execute("#{custom_field_key}_field") do
                connection.get_ticket_attribute_for_custom_value_named!(custom_field_name) rescue "undefined"
              end
              
              value_id = unfuddle_ticket[key]
              return nil if value_id.blank?
              find_in_cache_or_execute("#{custom_field_key}_value_#{value_id}") do
                connection.find_custom_field_value_by_id!(custom_field_name, value_id).value
              end
            rescue
              if retried_once
                raise
              else
                
                # If an error occurred above, it may be because
                # we cached the wrong value for something.
                retried_once = true
                invalidate_cache!("#{custom_field_key}_field", "#{custom_field_key}_value_#{value_id}")
                retry
              end
            end
          end
          
          
          
        private
          
          attr_reader :connection
          alias :unfuddle :connection
          
          delegate :find_in_cache_or_execute,
                   :invalidate_cache,
                   :to => :connection
          
          
          
          def get_type
            identify_type_proc = unfuddle.config[:identify_type]
            identify_type_proc.call(self) if identify_type_proc
          end
          
          def get_tags
            identify_tags_proc = unfuddle.config[:identify_tags]
            return [] unless identify_tags_proc
            identify_tags_proc.call(self)
          end
          
          def get_antecedents
            identify_antecedents_proc = unfuddle.config[:identify_antecedents]
            return [] unless identify_antecedents_proc
            identify_antecedents_proc.call(self)
          end
          
          
          
          def parse_prerequisites(associations)
            Array.wrap(associations)
              .select { |assocation| assocation["relationship"] == "parent" }
              .map { |assocation| assocation["ticket"]["number"] }
          end
          
          
          
          def get_severity_name(severity_id)
            severity = unfuddle.severities.find { |severity| severity.id == severity_id }
            severity && severity.name
          end
          
          
          
        end
      end
    end
  end
end