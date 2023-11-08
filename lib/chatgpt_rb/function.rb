module ChatgptRb
  class Function
    attr_accessor :name, :description, :parameters, :implementation

    # @param name [String, nil]
    # @param description [String, nil]
    # @param parameters [Array<ChatgptRb::Parameter>]
    # @param implementation [Lambda, nil]
    def initialize(name: nil, description: nil, parameters: [], implementation: nil)
      @name = name
      @description = description
      @parameters = parameters
      @implementation = implementation
    end

    def validate!
      metaschema = JSON::Validator.validator_for_name("draft4").metaschema
      return if JSON::Validator.validate(metaschema, as_json[:function])

      raise ArgumentError, "Invalid function declaration for #{name}: #{as_json[:function]}"
    end

    # @return [Hash]
    def as_json
      {
        type: "function",
        function: {
          name:,
          description:,
          parameters: {
            type: "object",
            properties: parameters.each_with_object({}) do |parameter, hash|
              hash[parameter.name] = parameter.as_json
            end,
            required: parameters.select(&:required?).map(&:name),
          },
        }.compact
      }
    end
  end
end
