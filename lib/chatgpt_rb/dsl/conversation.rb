require_relative "./base"
require_relative "./function"
require_relative "../function"

module ChatgptRb
  module DSL
    class Conversation < Base
      supported_fields %i[api_key model functions temperature max_tokens top_p frequency_penalty presence_penalty prompt]

      # @param name [String] the name of the function
      # @param configuration [Block]
      def function(name, &configuration)
        object.functions[name] = ChatgptRb::DSL::Function.configure(ChatgptRb::Function.new(name:), &configuration)
      end
    end
  end
end
