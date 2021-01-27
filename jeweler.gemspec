
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jeweler/version"

Gem::Specification.new do |spec|
  spec.name          = "rest_jeweler"
  spec.version       = Jeweler::VERSION
  spec.authors       = ["Christian Weyer"]
  spec.email         = ["cw@zaikio.com"]

  spec.summary       = 'A foundation for REST API consumption gems'
  spec.description   = 'REST jeweler is the foundation for quickly building gems that consume REST APIs'
  spec.homepage      = "https://www.github.com/crispymtn/jeweler"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'faraday'
  spec.add_dependency 'activesupport'
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
