class Milestone < ActiveRecord::Base
  extend Nosync
  
  belongs_to :project
  has_many :tickets, -> { reorder("NULLIF(tickets.extended_attributes->'milestoneSequence', '')::int") }
  
  versioned only: [:name, :start_date, :end_date, :band], class_name: "MilestoneVersion", initial_version: true
  
  default_scope { where(destroyed_at: nil).order(:start_date) }
  
  validates :project_id, presence: true
  validates :name, presence: true, uniqueness: {scope: :project_id}
  
  after_save :propagate_name_change, if: :name_changed?
  
  delegate :ticket_tracker, to: :project
  delegate :nosync?, to: "self.class"
  
  class << self
    def empty
      where(tickets_count: 0)
    end
    
    def populated
      where(arel_table[:tickets_count].gt(0))
    end
    
    def completed
      where(
        arel_table[:tickets_count].gt(0).and(
        arel_table[:closed_tickets_count].eq(arel_table[:tickets_count])))
    end
    
    def uncompleted
      where(
        arel_table[:tickets_count].eq(0).or(
        arel_table[:closed_tickets_count].lt(arel_table[:tickets_count])))
    end
    alias :open :uncompleted
    
    def visible
      where(arel_table[:start_date].not_eq(nil)).
      where(arel_table[:end_date].not_eq(nil))
    end
    
    def current
      during(Date.today..Date.today)
    end
    
    def during(range)
      visible
        .where(arel_table[:start_date].lteq(range.end))
        .where(arel_table[:end_date].gteq(range.begin))
    end
    
    def without(milestones)
      without_remote_ids(milestones.map(&:remote_id))
    end
    
    def without_remote_ids(*ids)
      where(arel_table[:remote_id].not_in(ids.flatten.map(&:to_i)))
    end
    
    def remote_id_map
      query = select("remote_id, id").to_sql
      connection.select_rows(query).each_with_object({}) { |(remote_id, id), map| map[remote_id.to_i] = id.to_i }
    end
    
    def id_for_remote_id(remote_id)
      return nil if remote_id.nil? or remote_id == 0
      where(remote_id: remote_id).pluck(:id).first
    end
  end
  
  
  
  def completed?
    tickets_count > 0 && closed_tickets_count == tickets_count
  end
  
  def uncompleted?
    !completed?
  end
  
  def close!
    project.ticket_tracker.close_milestone!(self) if project.ticket_tracker.respond_to?(:close_milestone!)
    touch :completed_at
  end
  
  def remote_milestone
    @remote_milestone ||= ticket_tracker.find_milestone(remote_id) if ticket_tracker.respond_to?(:find_milestone)
  end
  alias :remote :remote_milestone
  
  def update_closed_tickets_count!
    update_column :closed_tickets_count, tickets.closed.count
  end
  
private
  
  def propagate_name_change
    return if nosync?
    remote_milestone.update_name!(name) if remote_milestone.respond_to?(:update_name!)
  end
  
end
