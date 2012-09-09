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

    def initialize info
      reload info
    end

    # Reload data from Beeminder.
    #
    # @param info [Hash] Optionally reload with this info instead of getting it from Beeminder.
    def reload info=nil
      info ||= @user.get "users/me/goals/#{@slug}.json"

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
      info = @user.get "users/me/goals/#{slug}/datapoints.json"
      datapoints = info.map{|d| Datapoint.new d}

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

      @user.put "users/me/goals/#{@slug}.json", data
    end

    # Send new road setting to Beeminder.
    #
    # @param dials [Hash] Set exactly two of `"rate"`, `"goaldate"` and `"goalval"`. The third is implied.
    def dial_road dials={}
      raise "Set exactly two dials." if dials.keys.size != 2

      dials["goaldate"] = dials["goaldate"].strftime('%s') unless dials["goaldate"].nil?

      @user.post "users/me/goals/#{@slug}/dial_road.json", dials
    end
    
    # Add one or more datapoints to the goal.
    #
    # @param datapoints [Beeminder::Datapoint, Array<Beeminder::Datapoint>] one or more datapoints to add to goal
    def add datapoints, opts={}
      datapoints = [*datapoints]

      # FIXME create_all doesn't work because Ruby's POST encoding of arrays is broken.
      datapoints.each do |dp|
        data = {
          "sendmail"   => opts[:sendmail] || false
        }.merge(dp.to_hash)

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

    # Convert datapoint to hash for POSTing.
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

    def initialize info={}
      # set variables
      info.each do |k,v|
        instance_variable_set "@#{k}", v
      end

      # defaults
      @timestamp ||= DateTime.now
      @comment   ||= ""

      # some conversions
      @timestamp  = DateTime.strptime(@timestamp.to_s,  '%s') unless @timestamp.is_a? Date
      @updated_at = DateTime.strptime(@updated_at.to_s, '%s') unless @updated_at.nil?
    end

    def update
      # TODO
    end

    # Convert datapoint to hash for POSTing.
    # @return [Hash]
    def to_hash
      {
        "timestamp" => @timestamp.strftime('%s'),
        "value"     => @value || 0,
        "comment"   => @comment || "",
      }
    end
  end
end
