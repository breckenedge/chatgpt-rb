require "spec_helper"

describe ChatgptRb::DSL::Conversation do
  context "prompt" do
    let(:prompt) { "Act like a sullen teenager." }

    it "accepts a prompt via the DSL" do
      convo = ChatgptRb::Conversation.new do
        prompt "Act like a sullen teenager."
      end
      expect(convo.prompt).to eq("Act like a sullen teenager.")
    end
  end

  context "functions" do
    it "accepts functions passed via the configuration DSL" do
      convo = ChatgptRb::Conversation.new do
        function "get_current_weather" do
          description ""
          parameter "location" do
            type "string"
            description "The location, eg Dallas, TX"
            required true
          end
          implementation(->(location:) { nil })
        end

        function "get_stock_price" do
          description "Get the current price for a given stock"
          parameter "symbol" do
            type "string"
            description "The stock symbol, for example: 'SPX' or 'APPL'"
            required true
          end
          implementation(->(symbol:) { 100 })
        end
      end
      expect(convo.functions["get_current_weather"].name).to eq("get_current_weather")
      expect(convo.functions["get_current_weather"].parameters.first.name).to eq("location")
      expect(convo.functions["get_stock_price"].name).to eq("get_stock_price")
      expect(convo.functions["get_stock_price"].parameters.first.name).to eq("symbol")
    end
  end
end
