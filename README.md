# ChatgptRb

This is a library and CLI for interacting with the ChatGPT API from Ruby.

## Installation and Setup

Install this gem via the command line:

```sh
gem install chatgpt-rb
```

## CLI

![chatgpt-rb demo](demo.gif)

Set the `OPEN_AI_KEY` environment variable, then run the `chatgpt-rb` executable:

```sh
export OPEN_AI_KEY=foobarbaz
chatgpt-rb
Welcome to ChatGTP. Type any message to talk with ChatGPT. Type 'exit' to quit. Type 'dump' to dump this conversation to JSON.
me> Open the pod bay doors, Hal.
ai> I'm sorry, Dave. I'm afraid I can't do that.
me> exit
```

Alternatively, you can store this in a local `.env` file:

```sh
echo "OPEN_AI_KEY=foobarbaz" > .env
chatgpt-rb
```

## Usage

This gem can also be used as a library in your own app:

```ruby
require "chatgpt_rb"

ChatgptRb::Conversation.new(api_key: "foobarbaz").ask("Open the pod bay doors, Hal.")
# => "I'm sorry, Dave. I'm afraid I can't do that."
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
      required: ["location"],
    },
    implementation: ->(location:, unit: "celcius") {
      # Your code goes here. The result of this block gets passed back to ChatGPT as JSON.
      { temperature: 22, unit: unit || "celsius", description: "Sunny" }
    },
  },
]

conversation = ChatgptRb::Conversation.new(api_key: "foobarbaz", functions: functions)
converastion.ask("What's the weather like in Pheonix today?")
# => "The weather in Pheonix, AZ is 22 degrees and sunny."
```
