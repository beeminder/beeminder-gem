# coding: utf-8

module Beeminder
  class Goal
    # @return [String] The final part of the URL of the goal, used as an identifier.
    attr_accessor :slug

    # @return [DateTime] Last time this goal was updated.
    attr_reader :updated_at

    # @return [String] The title that the user specified for the goal. 
    attr_accessor :title

    # @return [DateTime] Goal date.
    attr_reader :goaldate

    # @return [Numeric] Goal value.
    attr_reader :goalval

    # @return [Numeric] The slope of the (final section of the) yellow brick road.
    attr_reader :rate

    # @return [Symbol] One of the following symbols:
    #   - `:fatloser`: Weight loss
    #   - `:hustler`: Do More
    #   - `:biker`: Odometer
    #   - `:inboxer`: Inbox Fewer
    #   - `:gainer`: Gain Weight
    #   - `:drinker`: Set a Limit
    #   - `:custom`: Full access to the underlying goal parameters
    attr_reader :goal_type

    # @return [DateTime] Date of derailment.
    attr_reader :losedate

    # @return [String] URL for the goal's graph image.
    attr_reader :graph_url

    # @return [Numeric] Panic threshold. How long before derailment to panic.
    attr_accessor :panic

    # @return [true|false] Whether the graph is currently being updated to reflect new data.
    attr_reader :queued

    # @return [true|false] Whether the graph was created in test mode.
    attr_accessor :ephem

    # @return [true|false] Whether you have to be signed in as owner of the goal to view it.
    attr_accessor :secret

    # @return [true|false] Whether you have to be signed in as the owner of the goal to view the datapoints.
    attr_accessor :datapublic

    # @return [Beeminder::User] User that owns this goal.
    attr_reader :user
    
    def initialize user, name
      @user = user
      @slug = name
      
      reload
    end

    # Reload data from Beeminder.
    def reload
      info = @user.get "users/#{@user.name}/goals/#{@slug}.json"

      # set variables
      info.each do |k,v|
        instance_variable_set "@#{k}", v
      end

      # some conversions
      @goaldate   = DateTime.strptime(@goaldate.to_s,   '%s') unless @goaldate.nil?
      @goal_type  = @goal_type.to_sym unless @goal_type.nil?
      @losedate   = DateTime.strptime(@losedate.to_s,   '%s') unless @losedate.nil?
      @updated_at = DateTime.strptime(@updated_at.to_s, '%s')
    end

    # List of datapoints.
    #
    # @return [Array<Beeminder::Datapoint>] returns list of datapoints
    def datapoints
      info = @user.get "users/#{@user.name}/goals/#{slug}.json", "datapoints" => true
      datapoints = info["datapoints"].map{|d| Datapoint.new d}

      datapoints
    end

    # Send updated info to Beeminder.
    def update
    end

    # Add one or more datapoints to the goal.
    #
    # @param datapoints [Beeminder::Datapoint, Array<Beeminder::Datapoint>] one or more datapoints to add to goal
    def add datapoints, opts={}
      opts = {:sendmail => false}.merge(opts)
      datapoints = [*datapoints]
    end

    # Delete one or more datapoints from the goal.
    #
    # @param datapoints [Beeminder::Datapoint, Array<Beeminder::Datapoint>] one or more datapoints to delete
    def delete datapoints
      datapoints = [*datapoints]
      datapoints.each{|d| d.delete}
    end
  end

  class Datapoint
    # @return [DateTime] Time of the datapoint.
    attr_accessor :timestamp

    # @return [Numeric] Value of the datapoint.
    attr_accessor :value

    # @return [String] An optional comment about the datapoint.
    attr_accessor :comment

    # @return [String] A unique ID, used to identify a datapoint when deleting or editing it.
    attr_reader :id

    # @return [DateTime] The time that this datapoint was entered or last updated.
    attr_reader :updated_at

    def initialize info
      # set variables
      info.each do |k,v|
        instance_variable_set "@#{k}", v
      end

      # some conversions
      @timestamp  = DateTime.strptime(@timestamp.to_s,  '%s')
      @updated_at = DateTime.strptime(@updated_at.to_s, '%s')
    end

    # Send updated info to Beeminder.
    def update
      
      # update
      @updated_at = DateTime.strptime(ret["updated_at"].to_s, '%s')
    end

    # Delete datapoint.
    def delete
    end
  end
end
