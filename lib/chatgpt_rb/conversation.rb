require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "httparty"
end

require "httparty"

module ChatgptRb
  class Conversation
    attr_reader :api_key, :model, :functions

    def initialize(api_key:, model: "gpt-3.5-turbo", functions: [])
      @api_key = api_key
      @model = model
      @functions = functions
      @messages = []
    end

    def <<(message)
      @messages << message
    end

    def ask(message)
      @messages << { role: "user", content: message }
      get_next_response
    end

    def get_next_response(temperature: 0.7, max_tokens: 1024, top_p: 1, frequency_penalty: 0, presence_penalty: 0, functions: [], &block)
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
          messages: @messages,
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

      @messages << if block_given? && streamed_content != ""
                     { "content" => streamed_content, "role" => streamed_role }
                   elsif block_given? && streamed_arguments != ""
                     { "role" => "assistant", "content" => nil, "function_call" => { "name" => streamed_function, "arguments" => streamed_arguments } }
                   else
                     response.dig("choices", 0, "message")
                   end

      if @messages.last["content"]
        @messages.last["content"]
      elsif @messages.last["function_call"]
        function_args = @messages.last["function_call"]
        function_name = function_args.fetch("name")
        arguments = JSON.parse(function_args.fetch("arguments"))

        function = functions.find { |function| function[:name] == function_name }
        content = function.fetch(:implementation).call(**arguments.transform_keys(&:to_sym))

        @messages << { role: "function", name: function_name, content: content.to_json }

        get_next_response(functions:, api_key:, model:, temperature:, max_tokens:, top_p:, frequency_penalty:, presence_penalty:, &block)
      end
    end
  end
end
