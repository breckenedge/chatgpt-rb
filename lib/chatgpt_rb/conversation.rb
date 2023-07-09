require "httparty"
require "json-schema"
require_relative "./function"
require_relative "./dsl/conversation"

module ChatgptRb
  class Conversation
    include HTTParty

    base_uri "https://api.openai.com"

    attr_accessor :api_key, :model, :functions, :temperature, :max_tokens, :top_p, :frequency_penalty, :presence_penalty, :prompt
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
    def initialize(api_key: nil, model: "gpt-3.5-turbo", functions: [], temperature: 0.7, max_tokens: 1024, top_p: 1.0, frequency_penalty: 0.0, presence_penalty: 0.0, messages: [], prompt: nil, &configuration)
      @api_key = api_key
      @model = model
      @functions = functions.each_with_object({}) do |function, hash|
        func = function.is_a?(ChatgptRb::Function) ? function : ChatgptRb::Function.new(**function)
        hash[func.name] = func
      end
      @temperature = temperature
      @max_tokens = max_tokens
      @top_p = top_p
      @frequency_penalty = frequency_penalty
      @presence_penalty = presence_penalty
      @messages = messages
      @prompt = prompt
      ChatgptRb::DSL::Conversation.configure(self, &configuration) if block_given?
      @messages << { role: "system", content: prompt } if prompt
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

    def <<(message)
      @messages << message
    end

    # Ensure that each function's argument declarations conform to the JSON Schema
    # See https://github.com/voxpupuli/json-schema/
    def validate_functions!
      metaschema = JSON::Validator.validator_for_name("draft4").metaschema
      functions.values.each do |function|
        raise ArgumentError, "Invalid function declaration for #{function.name}: #{function.as_json}" unless JSON::Validator.validate(metaschema, function.as_json)
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
        hash[:functions] = functions.values.map(&:as_json) unless functions.empty?
      end

      response = self.class.post(
        "/v1/chat/completions",
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
            next if line.nil?
            next if line == "\n"
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
        function = functions[function_name]
        content = function.implementation.call(**arguments.transform_keys(&:to_sym))

        @messages << { role: "function", name: function_name, content: content.to_json }

        get_next_response(&block)
      end
    end
  end
end
