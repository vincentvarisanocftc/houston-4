class WelcomeController < ApplicationController
  before_filter :authenticate_user!
  layout "minimal"
  
  def index
    load_activity
  end
  
  def activity
    load_activity
    render partial: "activity/events"
  end
  
private
  
  def load_activity
    if params[:since]
      time = Time.parse(params[:since])
      @last_date = time.to_date
    else
      time = Time.now
      @last_date = nil
    end
    
    @events = ActivityFeed.new(followed_projects, time, count: 150).events
  end
  
end
