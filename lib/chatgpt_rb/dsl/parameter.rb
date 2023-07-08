require_relative "./base"

module ChatgptRb
  module DSL
    class Parameter < Base
      supported_fields %i[description type enum required]
    end
  end
end
