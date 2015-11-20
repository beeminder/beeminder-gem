# -*- encoding: utf-8 -*-

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

    # @return [Numeric] Value of the most recent data point.
    attr_reader :curval

    # @return [DateTime] Date of the most recent data point.
    attr_reader :curday
    
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

    # @return [Array<Integer, Float, Float>] All road settings over time
    attr_accessor :roadall

    # @return [true|false] Whether the goal is currently frozen and therefore must be restarted before continuing to accept data.
    attr_reader :frozen
    
    def initialize user, name_or_info
      @user = user

      info =
        case name_or_info
        when String
          @user.get "users/me/goals/#{name_or_info}.json"
        when Hash
          name_or_info
        else
          raise ArgumentError, "`name_or_info` must be String (slug) or Hash (preloaded info)"
        end
      
      _parse_info info
    end

    # Reload data from Beeminder.
    def reload
      info = @user.get "users/me/goals/#{@slug}.json"
      _parse_info info
    end

    # List of datapoints.
    #
    # @return [Array<Beeminder::Datapoint>] returns list of datapoints
    def datapoints
      info = @user.get "users/me/goals/#{slug}/datapoints.json"
      datapoints = info.map do |d_info|
        d_info = {
          :goal => self,
        }.merge(d_info)

        Datapoint.new d_info
      end

      datapoints
    end

    # Send updated meta-data to Beeminder.
    def update
      data = {
        "slug"       => @slug,
        "title"      => @title,
        "ephem"      => @ephem || false,
        "panic"      => @panic || 86400,
        "secret"     => @secret || false,
        "datapublic" => @datapublic || false,
      }
      data['roadall'] = @roadall if @roadall

      @user.put_document "users/me/goals/#{@slug}.json", data
    end

    # Send new road setting to Beeminder.
    #
    # @param dials [Hash] Set exactly two of `"rate"`, `"goaldate"` and `"goalval"`. The third is implied.
    def dial_road dials={}
      raise "Set exactly two dials." if dials.keys.size != 2

      # convert to proper timestamp
      unless dials["goaldate"].nil?
        dials["goaldate"] = @user.convert_to_timezone dials["goaldate"] if @user.enforce_timezone?
        dials["goaldate"] = dials["goaldate"].strftime('%s')
      end
        
      @user.post "users/me/goals/#{@slug}/dial_road.json", dials
    end

    # Schedule a break.
    # Adds two new entries to `roadall` reflecting the break.
    # Use #update to actually update the goal.
    #
    # @param start_time [Time] when to start the break -- must be after the akrasia horizon
    # @param end_time [Time] when to end the break
    # @param rate [Float] the slope of the road during the break
    def schedule_break start_time, end_time, rate = 0.0
      check_break start_time, end_time

      roadall.insert(-2, [start_time.to_i, nil, roadall.last.last])
      roadall.insert(-2, [end_time.to_i, nil, rate])
    end
    
    # Add one or more datapoints to the goal.
    #
    # @param datapoints [Beeminder::Datapoint, Array<Beeminder::Datapoint>] one or more datapoints to add to goal
    def add datapoints, opts={}
      datapoints = [*datapoints]

      datapoints.each do |dp|
        # we grab these datapoints for ourselves
        dp.goal = self
        
        data = {
          "sendmail" => opts[:sendmail] || false
        }.merge(dp.to_hash)

        # TODO create_all doesn't work because Ruby's POST encoding of arrays is broken.
        @user.post "users/me/goals/#{@slug}/datapoints.json", data
      end
    end

    # Delete one or more datapoints from the goal.
    #
    # @param datapoints [Beeminder::Datapoint, Array<Beeminder::Datapoint>] one or more datapoints to delete
    def delete datapoints
      datapoints = [*datapoints]
      datapoints.each do |dp|
        @user.delete "/users/me/goals/#{@slug}/datapoints/#{dp.id}.json"
      end
    end

    # Convert goal to hash for POSTing.
    # @return [Hash]
    def to_hash
      {
        "slug"       => @slug,
        "title"      => @title,
        "goal_type"  => @goal_type.to_s,
        "ephem"      => @ephem || false,
        "panic"      => @panic || 86400,
        "secret"     => @secret || false,
        "datapublic" => @datapublic || false,
      }
    end

    private

    def check_break start_time, end_time
      akrasia_horizon = user.akrasia_horizon
      fail ArgumentError, "break start can't be before the akrasia horizon (#{akrasia_horizon})" \
          if start_time < akrasia_horizon
      fail ArgumentError, 'break must start before it ends' \
          unless end_time > start_time
    end

    def _parse_info info
      # set variables
      info.each do |k,v|
        instance_variable_set "@#{k}", v
      end

      # some conversions
      @goaldate   = DateTime.strptime(@goaldate.to_s,   '%s').in_time_zone(@user.timezone) unless @goaldate.nil?
      @goal_type  = @goal_type.to_sym unless @goal_type.nil?
      @losedate   = DateTime.strptime(@losedate.to_s,   '%s').in_time_zone(@user.timezone) unless @losedate.nil?
      @updated_at = DateTime.strptime(@updated_at.to_s, '%s').in_time_zone(@user.timezone)
      @curdate    = DateTime.strptime(@curdate.to_s,    '%s').in_time_zone(@user.timezone) unless @curdate.nil?

      # reported data is sometimes malformed like this
      roadall.last[0] = nil if !roadall.nil? && roadall.last[0] == 0
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

    # @return [Beeminder::Goal] Goal this datapoint belongs to.
    #   Optional for new datapoints. Use `Goal#add` to add new datapoints to a goal.
    attr_accessor :goal
    
    def initialize info={}
      # set variables
      info.each do |k,v|
        instance_variable_set "@#{k}", v
      end

      # defaults
      @timestamp ||= DateTime.now
      @comment   ||= ""

      # some conversions
      @timestamp  = DateTime.strptime(@timestamp.to_s,  '%s') unless @timestamp.is_a?(Date) || @timestamp.is_a?(Time)
      @updated_at = DateTime.strptime(@updated_at.to_s, '%s') unless @updated_at.nil?

      # set timezone if possible
      unless @goal.nil?
        @timestamp  = @timestamp.in_time_zone  @goal.user.timezone
        @updated_at = @updated_at.in_time_zone @goal.user.timezone
      end
    end

    # Convert datapoint to hash for POSTing.
    # @return [Hash]
    def to_hash
      if not @goal.nil? and @goal.user.enforce_timezone?
        @timestamp = @goal.user.convert_to_timezone @timestamp
      end
      
      {
        "timestamp" => @timestamp.strftime('%s'),
        "value"     => @value || 0,
        "comment"   => @comment || "",
      }
    end
  end
end
