module ChatgptRb
  module DSL
    class Base
      # @param object [Chatgpt::Conversation, ChatgptRb::Function, ChatgptRb::Parameter]
      # @param configuration [Block]
      # @return [Chatgpt::Conversation, ChatgptRb::Function, ChatgptRb::Parameter]
      def self.configure(object, &configuration)
        new(object).instance_eval(&configuration)
        object
      end

      attr_reader :object

      # @param object [Chatgpt::Conversation, ChatgptRb::Function, ChatgptRb::Parameter]
      def initialize(object)
        @object = object
      end

      # @param [Array<Symbol>] shorthand for allowing the DSL to set iVars
      def self.supported_fields(fields)
        fields.each do |method_name|
          define_method method_name do |value|
            object.public_send("#{method_name}=", value)
          end
        end
      end
    end
  end
end
