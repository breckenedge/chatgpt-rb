#!/usr/bin/env ruby

require "httparty"

FUNCTIONS = [
  {
    name: "get_current_weather",
    description: "Get the current weather in a given location",
    parameters: {
      type: "object",
      properties: {
        location: {
          type: "string",
          description: "The city and state, e.g. San Francisco, CA",
        },
        unit: {
          type: "string",
          enum: ["celcius", "fahrenheit"],
        }
      },
      required: ["location"],
    },
    implementation: ->(location:, unit: "celcius") {
      {
        temperature: 22,
        unit: unit || "celsius",
        description: "Sunny",
      }
    }
  },
  {
    name: "get_property_details",
    description: "Get the details for a given address",
    parameters: {
      type: "object",
      properties: {
        address: {
          type: "string",
          description: "The address of the property, e.g. 123 Main St, Dallas, TX 75238"
        }
      },
      required: ["location"],
    },
    implementation: ->(address:) {
      {
        bedrooms: 4,
        bathrooms: 2.5,
        year_build: 1964,
        last_sold: 2020
      }
    }
  }
]

def chat_response_for(
  messages = [],
  api_key: ENV.fetch("OPEN_AI_KEY"),
  model: ENV.fetch("OPEN_AI_MODEL", "gpt-3.5-turbo"),
  functions: FUNCTIONS,
  temperature: 0.7,
  max_tokens: 1024,
  top_p: 1,
  frequency_penalty: 0,
  presence_penalty: 0,
  &block
)
  streamed_content = ""
  streamed_arguments = ""
  streamed_role = ""
  streamed_function = ""
  error_buffer = []

  response = HTTParty.post(
    "https://api.openai.com/v1/chat/completions",
    steam_body: block_given?,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer #{api_key}",
    },
    body: {
      model:,
      messages:,
      temperature:,
      max_tokens:,
      top_p:,
      frequency_penalty:,
      presence_penalty:,
      stream: block_given?,
    }.tap { |hash| hash[:functions] = functions.map { |hash| hash.except(:implementation) } unless functions.empty? }.to_json,
  ) do |fragment|
    fragment.each_line do |line|
      next if line.nil?
      next if line == "\n"
      break if line == "data: [DONE]\n"

      line_without_prefix = line.gsub(/^data: /, "")
      json = JSON.parse(line_without_prefix)

      break if json.dig("choices", 0, "finish_reason")

      if (function_name = json.dig("choices", 0, "delta", "function_call", "name"))
        streamed_function = function_name
        next
      end

      if (role = json.dig("choices", 0, "delta", "role"))
        streamed_role = role
        next
      end

      if content = json.dig("choices", 0, "delta", "content")
        yield content unless line_without_prefix.empty?
        streamed_content << content
      elsif arguments = json.dig("choices", 0, "delta", "function_call", "arguments")
        streamed_arguments << arguments
      end
    rescue => e
      error_buffer << "Error: #{e}"
    end
  end

  error_buffer.each { |e| $stderr.puts("Error: #{e}") }

  messages << if block_given? && streamed_content != ""
                { "content" => streamed_content, "role" => streamed_role }
              elsif block_given? && streamed_arguments != ""
                { "role" => "assistant", "content" => nil, "function_call" => { "name" => streamed_function, "arguments" => streamed_arguments } }
              else
                response.dig("choices", 0, "message")
              end

  if messages.last["content"]
    messages.last["content"]
  elsif messages.last["function_call"]
    function_args = messages.last["function_call"]
    function_name = function_args.fetch("name")
    arguments = JSON.parse(function_args.fetch("arguments"))

    function = functions.find { |function| function[:name] == function_name }
    content = function.fetch(:implementation).call(**arguments.transform_keys(&:to_sym))

    messages << { role: "function", name: function_name, content: content.to_json }

    chat_response_for(messages, functions:, api_key:, model:, temperature:, max_tokens:, top_p:, frequency_penalty:, presence_penalty:, &block)
  end
end

if $0 == __FILE__
  require "bundler/inline"

  gemfile do
    source "https://rubygems.org"
    gem "colorize"
    gem "dotenv"
    gem "httparty"
  end

  require "dotenv/load"
  require "colorize"

  messages = []

  puts "Welcome to ChatGTP. Type any message to talk with ChatGPT. Type 'exit' to quit. Type 'dump' to dump this conversation to JSON."

  loop do
    print("me> ".colorize(:red))
    message = gets.chomp

    case message
    when "exit", "quit", "q", "\\q"
      exit
    when "dump"
      puts "#{':'.colorize(:blue)} #{messages.to_json}"
    else
      messages << { role: "user", content: message }
      print("ai> ".colorize(:green))
      chat_response_for(messages) { |fragment| print(fragment) }
      puts
    end
  end
end
