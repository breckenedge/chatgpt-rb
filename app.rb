require "bundler/setup"
Bundler.setup(:default)
require "dotenv/load"
require "httparty"

def embeddings_for(input, api_key: ENV.fetch("OPEN_AI_KEY"), model: "text-embedding-ada-002")
  HTTParty.post(
    "https://api.openai.com/v1/embeddings",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer #{api_key}"
    },
    body: {
      model:,
      input:,
    }.to_json,
  )
end

FUNCTIONS = [
#  {
#    name: "get_current_weather",
#    description: "Get the current weather in a given location",
#    parameters: {
#      type: "object",
#      properties: {
#        location: {
#          type: "string",
#          description: "The city and state, e.g. San Francisco, CA",
#        },
#        unit: {
#          type: "string",
#          enum: ["celcius", "fahrenheit"],
#        }
#      },
#      required: ["location"],
#    },
#  },
#  {
#    name: "get_property_details",
#    description: "Get the details for a given address",
#    parameters: {
#      type: "object",
#      properties: {
#        address: {
#          type: "string",
#          description: "The address of the property, e.g. 123 Main St, Dallas, TX 75238"
#        }
#      },
#      required: ["location"],
#    }
#  }
]

def current_weather_for(location:, unit: "celcius")
  {
    temperature: 22,
    unit: unit || "celsius",
    description: "Sunny",
  }
end

def property_details_for(address:)
  {
    bedrooms: 4,
    bathrooms: 2.5,
    year_build: 1964,
    last_sold: 2020
  }
end

# @param messages [Array<Hash>]
# @param functions [Array<Hash>]
# @param api_key [String]
# @param model [String]
# @param temperature [Float]
# @param max_tokens [Integer]
# @param top_p [Integer]
# @param frequency_penalty [Float]
# @param presence_penalty [Float]
# @yieldcontent [String] the current chunk of the streamed message if a block is passed
def chat_response_for(messages = [], functions: FUNCTIONS, api_key: ENV.fetch("OPEN_AI_KEY"), model: "gpt-3.5-turbo", temperature: 0.7, max_tokens: 1024, top_p: 1, frequency_penalty: 0, presence_penalty: 0)
  streamed_content = ""
  streamed_role = ""

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
    }.tap do |hash|
      hash[:functions] = functions unless functions.empty?
    end.to_json,
  ) do |fragment|
    fragment.each_line do |line|
      next if line.nil?
      line_without_prefix = line.gsub(/^data: /, "")
      json = JSON.parse(line_without_prefix)
      if role = json.dig("choices", 0, "delta", "role")
        streamed_role = role
        next
      end
      content = json.dig("choices", 0, "delta", "content")
      yield content unless line_without_prefix.empty?
      streamed_content << content
    rescue JSON::ParserError
    rescue => e
      $stderr.puts(e)
    end
  end

  messages << if block_given?
                { "content" => streamed_content, "role" => streamed_role }
              else
                response.dig("choices", 0, "message")
              end

  if messages.last["content"]
    messages.last["content"]
  elsif messages.last["function_call"]
    function_args = messages.last["function_call"]
    function = function_args.fetch("name")
    arguments = JSON.parse(function_args.fetch("arguments"))

    data = case function
          when "get_current_weather"
            current_weather_for(location: arguments["location"], unit: arguments["unit"])
          when "get_property_details"
            property_details_for(address: arguments["address"])
          else
            raise "unknown function #{function}"
          end

    messages << { role: "function", name: function, content: data.to_json }
    chat_response_for(messages, functions:, api_key:, model:, temperature:, max_tokens:, top_p:, frequency_penalty:, presence_penalty:)
  end
end
