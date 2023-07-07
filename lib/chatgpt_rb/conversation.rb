require "httparty"

module ChatgptRb
  class Conversation
    attr_reader :api_key, :model, :functions, :temperature, :max_tokens, :top_p, :frequency_penalty, :presence_penalty, :messages

    # @param api_key [String]
    # @param model [String]
    # @param functions [Array<Hash>]
    # @param temperature [Float]
    # @param max_tokens [Integer]
    # @param top_p [Float]
    # @param frequency_penalty [Float]
    # @param presence_penalty [Float]
    # @param messages [Array<Hash>]
    # @param prompt [String, nil] instructions that the model can use to inform its responses, for example: "Act like a sullen teenager."
    def initialize(api_key:, model: "gpt-3.5-turbo", functions: [], temperature: 0.7, max_tokens: 1024, top_p: 1.0, frequency_penalty: 0.0, presence_penalty: 0.0, messages: [], prompt: nil)
      @api_key = api_key
      @model = model
      @functions = functions
      @temperature = temperature
      @max_tokens = max_tokens
      @top_p = top_p
      @frequency_penalty = frequency_penalty
      @presence_penalty = presence_penalty
      @messages = messages
      @messages << { role: "system", content: prompt } if prompt
    end

    # @param content [String]
    def ask(content, &block)
      @messages << { role: "user", content: }
      get_next_response(&block)
    end

    private

    def <<(message)
      @messages << message
    end

    def get_next_response(&block)
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
        if block_given?
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
