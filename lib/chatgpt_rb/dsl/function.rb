require_relative "../parameter"
require_relative "./parameter"

module ChatgptRb
  module DSL
    class Function < Base
      supported_fields %i[description implementation parameters]

      def parameter(name, &configuration)
        object.parameters << ChatgptRb::DSL::Parameter.configure(ChatgptRb::Parameter.new(name:), &configuration)
      end
    end
  end
end
