require_relative "./lib/chatgpt_rb/version"

Gem::Specification.new do |spec|
  spec.name          = "chatgpt-rb"
  spec.version       = ChatgptRb::VERSION
  spec.authors       = ["Aaron Breckenridge"]
  spec.email         = ["aaron@breckridge.dev"]
  spec.summary       = "A gem for interacting with the ChatGPT API"
  spec.description   = "Provides libraries for interacting with the ChatGPT API and a CLI program `chatgpt-rb` for live conversations. Supports writing tools (functions) in Ruby and streaming responses."
  spec.homepage      = "https://github.com/breckenedge/chatgpt-rb"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*", "bin/**/*"]
  spec.require_paths = ["lib"]
  spec.executables << "chatgpt-rb"
  spec.add_dependency "httparty", "~> 0.21"
  spec.add_dependency "colorize", "~> 0.6"
  spec.add_dependency "dotenv", "~> 2.8"
  spec.add_dependency "reline", "~> 0.3"
  spec.add_dependency "json-schema", "~> 4.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "listen"
  spec.add_development_dependency "webmock"
end
