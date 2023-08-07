function "get_current_weather" do
  description "Get the current weather for a given location"

  parameter "location" do
    type "string"
    description "The location, eg Dallas, Texas"
    required true
  end

  parameter "unit" do
    type "string"
    enum ["celcius", "fahrenheit"]
    description "The units to return the temperature in"
  end

  implementation(->(location:, unit: "celcius") do
    { temperature: 22, unit: unit || "celsius", description: "Sunny" }
  end)
end

function "get_stock_price" do
  description "Get the current price for a given stock"
  parameter "symbol" do
    type "string"
    description "The stock symbol, for example: 'SPX' or 'AAPL'"
    required true
  end
  implementation(->(symbol:) { 100 })
end
