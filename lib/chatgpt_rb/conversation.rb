require "httparty"
require "json-schema"
require_relative "./function"
require_relative "./dsl/conversation"

module ChatgptRb
  class Conversation
    attr_accessor :api_key, :model, :functions, :temperature, :max_tokens, :top_p, :frequency_penalty, :presence_penalty, :prompt, :base_uri, :seed, :json
    attr_reader :messages

    # @param api_key [String]
    # @param model [String]
    # @param functions [Array<Hash>, Array<ChatgptRb::Function>]
    # @param temperature [Float]
    # @param max_tokens [Integer]
    # @param top_p [Float]
    # @param frequency_penalty [Float]
    # @param presence_penalty [Float]
    # @param messages [Array<Hash>]
    # @param prompt [String, nil] instructions that the model can use to inform its responses, for example: "Act like a sullen teenager."
    # @param json [true, false] whether or not ChatGPT should respond using only JSON objects
    # @param seed [Integer, nil] deterministic best effort
    # @param base_uri [String]
    def initialize(api_key: nil, model: "gpt-3.5-turbo", functions: [], temperature: 0.7, max_tokens: 1024, top_p: 1.0, frequency_penalty: 0.0, presence_penalty: 0.0, messages: [], prompt: nil, base_uri: "https://api.openai.com/v1", json: false, seed: nil, &configuration)
      @api_key = api_key
      @model = model
      @functions = functions.each_with_object({}) do |function, hash|
        func = if function.is_a?(ChatgptRb::Function)
                 function
               else
                 parameters = function.dig(:parameters, :properties)&.map do |name, definition|
                   required = function.dig(:parameters, :required)&.include?(name)
                   ChatgptRb::Parameter.new(name:, required:, **definition)
                 end || []
                 ChatgptRb::Function.new(parameters:, **function.except(:parameters))
               end
        hash[func.name] = func
      end
      @temperature = temperature
      @max_tokens = max_tokens
      @top_p = top_p
      @frequency_penalty = frequency_penalty
      @presence_penalty = presence_penalty
      @messages = messages.map { |message| message.transform_keys(&:to_sym) }
      @prompt = prompt
      @base_uri = base_uri
      @json = json
      @seed = seed
      ChatgptRb::DSL::Conversation.configure(self, &configuration) if block_given?
      @messages.unshift(role: "system", content: prompt) if prompt
    end

    # @param content [String]
    # @yieldparam [String] the response, but streamed
    # @return [String] the response
    def ask(content, &block)
      @messages << { role: "user", content: }
      get_next_response(&block)
    end

    # @param content [String]
    # @param function [ChatgptRb::Function] temporarily enhance the next response with the provided function
    # @yieldparam [String] the response, but streamed
    # @return [String] the response
    def ask_with_function(content, function, &block)
      function_was = functions[function.name]
      functions[function.name] = function
      get_next_response(content, &block)
      functions[function.name] = function_was
    end

    private

    # Ensure that each function's argument declarations conform to the JSON Schema
    # See https://github.com/voxpupuli/json-schema/
    def validate_functions!
      metaschema = JSON::Validator.validator_for_name("draft4").metaschema
      functions.values.each do |function|
        raise ArgumentError, "Invalid function declaration for #{function.name}: #{function.as_json}" unless JSON::Validator.validate(metaschema, function.as_json[:function])
      end
    end

    def get_next_response(&block)
      validate_functions!

      streamed_content = ""
      streamed_arguments = ""
      streamed_role = ""
      streamed_function = ""
      error_buffer = []

      body = {
        model:,
        messages: @messages,
        temperature:,
        max_tokens:,
        top_p:,
        frequency_penalty:,
        presence_penalty:,
        stream: block_given?,
      }.tap do |hash|
        hash[:tools] = functions.values.map(&:as_json) unless functions.empty?
        hash[:response_format] = { type: :json_object } if json
        hash[:seed] = seed unless seed.nil?
      end

      response = HTTParty.post(
        "#{base_uri}/chat/completions",
        steam_body: block_given?,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{api_key}",
          "Accept" => "application/json",
          "User-Agent" => "Ruby/chatgpt-rb",
        },
        body: body.to_json,
      ) do |fragment|
        if block_given?
          fragment.each_line do |line|
            break if line == "data: [DONE]\n"

            line_without_prefix = line.gsub(/^data: /, "").rstrip

            next if line_without_prefix.empty?

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
      end

      raise APIError.new, response.body unless response.success?

      error_buffer.each { |e| $stderr.puts("Error: #{e}") }

      @messages << if block_given? && streamed_content != ""
                     { content: streamed_content, role: streamed_role }
                   elsif block_given? && streamed_arguments != ""
                     { role: "assistant", content: nil, function_call: { "name" => streamed_function, "arguments" => streamed_arguments } }
                   else
                     response.dig("choices", 0, "message").transform_keys(&:to_sym)
                   end

      if @messages.last[:content]
        json ? JSON.parse(@messages.last[:content]) : @messages.last[:content]
      elsif @messages.last[:tool_calls]
        @messages.last[:tool_calls].each do |tool_call|
          next unless tool_call.fetch("type") == "function"
          function_name = tool_call.dig("function", "name")
          function_args = JSON.parse(tool_call.dig("function", "arguments"))
          function = functions.fetch(function_name)
          content = function.implementation.call(**function_args.transform_keys(&:to_sym))
          @messages << {
            role: "tool",
            tool_call_id: tool_call.fetch("id"),
            name: function_name,
            content: content.to_json,
          }
        end

        get_next_response(&block)
      elsif @messages.last[:function_call]
        function_args = @messages.last[:function_call]
        function_name = function_args.fetch("name")
        arguments = JSON.parse(function_args.fetch("arguments"))
        function = functions[function_name]
        content = function.implementation.call(**arguments.transform_keys(&:to_sym))

        @messages << { role: "function", name: function_name, content: content.to_json }

        get_next_response(&block)
      end
    end
  end

  # Raised when the API responds with an error.
  class APIError < StandardError; end
end
