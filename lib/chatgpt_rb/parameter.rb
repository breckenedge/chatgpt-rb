module ChatgptRb
  class Parameter
    attr_accessor :name, :enum, :type, :description, :required

    # @param name [String]
    # @param enum
    # @param type
    # @param description
    # @param required [true, false] whether or not this parameter is required
    def initialize(name:, enum: nil, type: nil, description: nil, required: false)
      @name = name
      @enum = enum
      @type = type
      @description = description
      @required = required
    end

    def required?
      !!required
    end

    # @return Hash
    def as_json
      {
        enum:,
        type:,
        description:,
      }.compact
    end
  end
end
