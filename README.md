# Beeminder

Convenient access to [Beeminder](http://www.beeminder.com)'s API.

## Installation

Add this line to your application's Gemfile:

    gem 'beeminder'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install beeminder-gem

## Usage

First, get your token [here](https://www.beeminder.com/api/v1/auth_token.json) and log in:

    # normal login
    bee = Beeminder::User.new "token"

    # oauth
    bee = Beeminder::User.new "token", :auth_type => :oauth

Now you can do a bunch of stuff. You'll probably want to send a new datapoint:

    # short form
    bee.send "weight", 86.3

    # long form
    goal = bee.goal "weight"
    dp = Beeminder::Datapoint.new :value => 86.3, :comment => "I loves cheeseburgers :3"
    goal.add dp

Or you can find all goals of a certain type:

    odometer_goals = bee.goals.select {|g| g.goal_type == :biker}

Or maybe show the last updated graph in a widget somewhere:

    puts bee.goals.max_by{|g| g.updated_at}.graph_url

There's also a simple tool called `beemind` to update graphs:

    $ beemind pushups 4

Check the [gem doc](http://rubydoc.info/gems/beeminder/frames) and [API](https://www.beeminder.com/api-docs) for what else you can do.
