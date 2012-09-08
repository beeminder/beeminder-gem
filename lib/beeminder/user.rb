# coding: utf-8

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
    
    def initialize token
      @token = token

      info = get "users/me.json"

      @name       = info["username"]
      @timezone   = info["timezone"]
      @updated_at = DateTime.strptime(info["updated_at"].to_s, '%s')
    end

    # List of goals.
    #
    # @param filter [Symbol] filter goals, can be `:all` (default), `:frontburner` or `:backburner`
    # @ return [Array<Beeminder::Goal>] returns list of goals
    def goals filter=:all
      raise "invalid goal filter: #{filter}" unless [:all, :frontburner, :backburner].include? filter

      goals = get("users/#{@name}/goals.json", :filter => filter.to_s) || []
      goals.map! do |info|
        Beeminder::Goal.new info
      end

      goals || []
    end

    # Return specific goal.
    #
    # @param name [String] Name of the goal.
    # @return [Beeminder::Goal] Returns goal.
    def goal name
      info = @user.get "users/me/goals/#{@slug}.json"
      Beeminder::Goal.new info
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

    private

    # Establish HTTPS connection to API.
    def _connection type, cmd, data
      api  = "https://www.beeminder.com/api/v1/#{cmd}"
      data = {"auth_token" => @token}.merge(data)
      
      url = URI.parse(api)
      http = Net::HTTP.new(url.host, url.port)
      http.read_timeout = 8640
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE # FIXME: actually verify
      
      json = ""
      http.start do |http|
        req = case type
              when :post
                Net::HTTP::Post.new(url.path)
              when :get
                Net::HTTP::Get.new(url.path)
              when :delete
                Net::HTTP::Delete.new(url.path)
              when :put
                Net::HTTP::Put.new(url.path)
              else
                raise "invalid connection type"
              end
        req.set_form_data(data)
        
        res = http.request(req)
        if not res.is_a? Net::HTTPSuccess
          raise "request failed: #{res.body}"
        end

        json = res.body
      end

      # parse json
      json = JSON.load(json)

      json
    end
  end
end
