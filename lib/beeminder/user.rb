# -*- encoding: utf-8 -*-

module Beeminder
  class User
    # @return [String] User name.
    attr_reader :name

    # @return [String] Auth token.
    attr_reader :token

    # @return [DateTime] Last time user made any changes.
    attr_reader :updated_at

    # @return [String] Timezone.
    attr_reader :timezone

    # @return [Symbol] Type of user, can be `:personal` (default) or `:oauth`.
    attr_reader :auth_type

    # @return [true|false] Enforce user timezone for all passed times? Should be true unless you know what you're doing. (Default: `true`.)
    attr_accessor :enforce_timezone
    
    def initialize token, opts={}
      opts = {
        :auth_type => :personal,
        :enforce_timezone => true,
      }.merge(opts)
      
      @token            = token
      @auth_type        = opts[:auth_type]
      @enforce_timezone = opts[:enforce_timezone]

      @token_type =
        case @auth_type
        when :personal
          "auth_token"
        when :oauth
          "access_token"
        else
          raise ArgumentError, "Auth type not supported, must be :personal or :oauth."
        end
      
      info = get "users/me.json"

      @name       = info["username"]
      @timezone   = info["timezone"] || "UTC"
      @updated_at = DateTime.strptime(info["updated_at"].to_s, '%s').in_time_zone(@timezone)
    end

    # Enforce timezone for all passed times? 
    #
    # @return [true|false]
    def enforce_timezone?
      !!@enforce_timezone
    end
    
    # List of goals.
    #
    # @param filter [Symbol] filter goals, can be `:all` (default), `:frontburner` or `:backburner`
    # @return [Array<Beeminder::Goal>] returns list of goals
    def goals filter=:all
      raise "invalid goal filter: #{filter}" unless [:all, :frontburner, :backburner].include? filter

      goals = get("users/#{@name}/goals.json", :filter => filter.to_s) || []
      goals.map! do |info|
        Beeminder::Goal.new self, info
      end

      goals || []
    end

    # Return specific goal.
    #
    # @param name [String] Name of the goal.
    # @return [Beeminder::Goal] Returns goal.
    def goal name
      Beeminder::Goal.new self, name
    end

    # Convenience function to add datapoint to a goal.
    #
    # @param name [String] Goal name.
    # @param value [Numeric] Datapoint value.
    # @param comment [String] Optional comment.
    def send name, value, comment=""
      goal = self.goal name
      dp = Beeminder::Datapoint.new :value => value, :comment => comment
      goal.add dp
    end
    
    # Create new goal.
    #
    # @param opts [Hash] Goal options.
    def create_goal opts={}
      post "users/#{@name}/goals.json", opts
    end

    # Send GET request to API.
    #
    # @param cmd [String] the API command, like `users/#{user.name}.json`
    # @param data [Hash] data to send; auth_token is included by default (optional)
    def get cmd, data={}
      _connection :get, cmd, data
    end

    # Send POST request to API.
    #
    # @param cmd [String] the API command, like `users/#{user.name}.json`
    # @param data [Hash] data to send; auth_token is included by default (optional)
    def post cmd, data={}
      _connection :post, cmd, data
    end

    # Send DELETE request to API.
    #
    # @param cmd [String] the API command, like `users/#{user.name}.json`
    # @param data [Hash] data to send; auth_token is included by default (optional)
    def delete cmd, data={}
      _connection :delete, cmd, data
    end

    # Send PUT request to API.
    #
    # @param cmd [String] the API command, like `users/#{user.name}.json`
    # @param data [Hash] data to send; auth_token is included by default (optional)
    def put cmd, data={}
      _connection :put, cmd, data
    end

    # Converts time object to one with user's timezone.
    #
    # @param time [Date|DateTime|Time] Time to convert.
    # @return [Time] Converted time.
    def convert_to_timezone time
      Time.use_zone(@timezone){
      
      time = time.to_time unless time.is_a?(Time)
      Time.local(time.year, time.month, time.day, time.hour, time.min, time.sec)
      
      }
    end

    private
    
    # Establish HTTPS connection to API.
    def _connection type, cmd, data
      api  = "https://www.beeminder.com/api/v1/#{cmd}"
      data = {@token_type => @token}.merge(data)
      
      url = URI.parse(api)
      http = Net::HTTP.new(url.host, url.port)
      http.read_timeout = 8640
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE # FIXME: actually verify

      # FIXME Sanity check for wrong timestamp. Source of bug unknown, but at least we can prevent screwing up someone's graph.
      unless data["timestamp"].nil?
        if not data["timestamp"].match(/^\d+$/) or data["timestamp"] < "1280000000"
          raise ArgumentError, "invalid timestamp: #{data["timestamp"]}"
        end
      end
      
      json = ""
      http.start do |http|
        case type
        when :post
          req = Net::HTTP::Post.new(url.path)
          req.set_form_data(data)
        when :get
          req = Net::HTTP::Get.new(url.path + "?" + data.to_query)
        when :delete
          req = Net::HTTP::Delete.new(url.path + "?" + data.to_query)
        when :put
          req = Net::HTTP::Put.new(url.path)
          req.set_form_data(data)
        else
          raise "invalid connection type"
        end

        res = http.request(req)
        if not res.is_a? Net::HTTPSuccess
          raise "request failed: #{res.code} / #{res.body}"
        end

        json = res.body
      end

      # parse json
      json = JSON.load(json)

      json
    end
  end
end
