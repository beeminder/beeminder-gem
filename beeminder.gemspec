# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'beeminder/version'

Gem::Specification.new do |gem|
  gem.name          = "beeminder"
  gem.version       = Beeminder::VERSION
  gem.authors       = ["muflax"]
  gem.email         = ["mail@muflax.com"]
  gem.description   = "Convenient access to Beeminder's API."
  gem.summary       = "access Beeminder API"
  gem.homepage      = "https://github.com/beeminder/beeminder-gem"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.add_dependency 'activesupport', ['>= 3.2', '< 8']
  gem.add_dependency 'chronic', '~> 0.7'
  gem.add_dependency 'json'
  gem.add_dependency 'highline', '~> 1.6'
  gem.add_dependency 'optimist', '~> 3'
  gem.add_dependency 'tzinfo'
end
