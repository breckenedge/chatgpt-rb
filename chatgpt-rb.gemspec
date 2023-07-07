Gem::Specification.new do |spec|
  spec.name          = "chatgpt-rb"
  spec.version       = "0.1.0"
  spec.authors       = ["Aaron Breckenridge"]
  spec.email         = ["aaron@breckridge.dev"]
  spec.summary       = "A gem for interacting with the ChatGPT API"
  spec.description   = "Provides libraries for interacting with the ChatGPT API and a CLI program `chatgpt-rb` for live conversations."
  spec.homepage      = "https://github.com/breckenedge/chatgpt-rb"
  spec.license       = "MIT" # or any other license
  spec.files         = Dir["lib/**/*", "bin/**/*"]
  spec.require_paths = ["lib"]
  spec.executables << "chatgpt-rb"
  spec.add_dependency "httparty", ">= 0.21.0"
  spec.add_dependency "colorize", ">= 0.6.0"
  spec.add_dependency "dotenv", ">= 2.8.1"
  spec.add_dependency "reline", ">= 0.3.5"
end
