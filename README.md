# ChatgptRb

[![Specs](https://github.com/breckenedge/chatgpt-rb/actions/workflows/spec.yml/badge.svg)](https://github.com/breckenedge/chatgpt-rb/actions/workflows/spec.yml)

This is a library and CLI for interacting with the ChatGPT API from Ruby.

## Installation and Setup

Install this gem via the command line:

```sh
gem install chatgpt-rb
chatgpt-rb -k <Your OpenAI API Key>
```

Alternatively, set an `OPEN_AI_KEY` environment variable to avoid having to enter your key.

To see all usage options:

```sh
chatgpt-rb -h
```

### with Function Declarations

OpenAI's API is capable of calling external user defined functions. The CLI supports loading these functions from a functions definition file. See the [examples/functions.rb](examples/functions.rb) file for more in-depth examples.

```sh
chatgpt-rb -u ./examples/functions.rb
Type any message to talk with ChatGPT. Type '\help' for a list of commands.
Loading functions from ./examples/functions.rb
me> \functions
available functions:
- `get_current_weather` Get the current weather for a given location
```

Here's an example of a functions file:

```ruby
# in weather.rb
function "get_current_weather" do
  description "Get the current weather for a given location"

  parameter "location" do
    type "string"
    description "The location, eg Dallas, Texas"
    required true
  end

  parameter "unit" do
    type "string"
    enum ["celcius", "fahrenheit"]
    description "The units to return the temperature in"
  end

  implementation(->(location:, unit: "celcius") do
    { temperature: 22, unit: unit || "celsius", description: "Sunny" }
  end)
end
```

## Usage

This gem can also be used as a library in your own app:

```ruby
require "chatgpt_rb"

ChatgptRb::Conversation.new(api_key: "foobarbaz").ask("Open the pod bay doors, Hal.")
# => "I'm sorry, Dave. I'm afraid I can't do that."
```

### Streaming responses

You can configure the client to stream responses instead of waiting for the full response to arrive. To do this, pass a block to the conversation's `#ask` method:

```ruby
tokens = []

conversation = ChatgptRb::Conversation.new(api_key: "foobarbaz")

conversation.ask("Open the pod bay doors, Hal.") do |token|
  tokens << token
end

tokens
# => ["I", " sorry", ", ", " Dave", ".", " I", "'m", " afraid", " I", " can", "'t", " do", " that", "."]
```

## Prompts

You can pass in a custom prompt via via the DSL:

```ruby
conversation = ChatgptRb::Conversation.new(api_key: "foobarbaz") do
  prompt "You're a sullen teenager."
end

conversation.ask "How's it going today?"
# => Ugh, like who cares? The world's gonna end anyway.
```

Or as an initialization argument:

```ruby
conversation = ChatgptRb::Conversation.new(api_key: "foobarbaz", prompt: "You're a sullen teenager.")
```

## Functions

This library supports the OpenAI ChatGPT function calling syntax, which you can either pass in via the configuration DSL:

```ruby
conversation = ChatgptRb::Conversation.new(api_key: "foobarbaz") do
  function "get_current_weather" do
    description "Get the current weather for a given location"

    parameter  "location" do
      type "string"
      description "The location, eg Dallas, Texas"
      required true
    end

    parameter "unit" do
      type "string"
      enum ["celcius", "fahrenheit"]
    end

    implementation(->(location:, unit: "celcius") do
      # Your code goes here. The result of this block gets passed back to ChatGPT as JSON.
      { temperature: 22, unit: unit || "celsius", description: "Sunny" }
    end)
  end
end

conversation.ask("What's the weather today in Pheonix?")
# => The weather in Pheonex, Arizona, is currently sunny and 22 degrees.
```

Alternatively, you can pass your functions in as an initialization argument:

```ruby
functions = [
  {
    name: "get_current_weather",
    description: "",
    parameters: {
      type: "object",
      properties: {
        location: {
          type: "string",
          description: "",
        },
        unit: {
          type: "string",
          enum: ["celcius", "fahrenheit"],
        },
      },
      required: [:location],
    },
    implementation: ->(location:, unit: "celcius") {
      # Your code goes here. The result of this block gets passed back to ChatGPT as JSON.
      { temperature: 22, unit: unit || "celsius", description: "Sunny" }
    },
  },
]

conversation = ChatgptRb::Conversation.new(api_key: "foobarbaz", functions: functions)
conversation.ask("What's the weather like in Pheonix today?")
# => "The weather in Pheonix, AZ is 22 degrees and sunny."
```
