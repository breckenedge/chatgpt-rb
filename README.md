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

conversation = ChatgptRb::Conversation.new(api_key: "foobarbaz")
conversation.ask("Open the pod bay doors, Hal.")
# => "I'm sorry, Dave. I'm afraid I can't do that."
```

## Functions

This library supports the OpenAI ChatGPT function calling syntax. Note that the functions have a very strict format. Here's an illustrated example:

```ruby
require "chatgpt_rb"

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
      # Your code goes here. It gets passed back to ChatGPT.
      {
        temperature: 22,
        unit: unit || "celsius",
        description: "Sunny",
      },
    },
  },
]

conversation = ChatgptRb::Conversation.new(api_key: "foobarbaz", functions: functions)
converastion.ask("What's the weather like in Dallas today?")
# => "The weather in Dallas, TX is 22 degrees and sunny."
