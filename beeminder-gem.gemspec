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
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]
end
