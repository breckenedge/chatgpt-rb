require "spec_helper"

describe ChatgptRb::Conversation do
  it "takes a seed argument" do
    subject = described_class.new(seed: 1)
    expect(subject.seed).to eq(1)
  end

  context "prompt" do
    let(:prompt) { "Act like a sullen teenager." }
    let(:convo) { described_class.new(prompt:) }

    it "accepts a prompt as an argument" do
      expect(convo.prompt).to eq(prompt)
    end

    it "stores the prompt as the first message" do
      expect(convo.messages.first.fetch(:role)).to eq("system")
      expect(convo.messages.first.fetch(:content)).to eq(prompt)
    end
  end

  it "conducts conversations using only JSON responses" do
    mock_response = {
      id: "chatcmpl-7a6l2cVOW7rY9YescrcLZnxImdMYN",
      object: "chat.completion",
      created: 1688840140,
      model: "gpt-3.5-turbo-1106",
      choices: [
        {
          index: 0,
          message: {
            role: "assistant",
            content: { "response" => "I'm just a program, so I don't have feelings, but I'm here and ready to help you!" }.to_json,
          },
          finish_reason: "stop",
        }
      ],
      usage: {
        prompt_tokens: 12,
        completion_tokens: 47,
        total_tokens: 59,
      },
    }
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(body: {
        model: "gpt-3.5-turbo-1106",
        messages: [
          {
            role: "system",
            content: "Respond using only JSON."
          },
          {
            role: "user",
            content: "How are you today?"
          }
        ],
        temperature: 0.7,
        max_tokens: 1024,
        top_p: 1.0,
        frequency_penalty: 0.0,
        presence_penalty: 0.0,
        stream: false,
        response_format: { type: "json_object" }
      }.to_json)
      .to_return(headers: { "Content-Type" => "application/json" }, body: mock_response.to_json)

    convo = described_class.new(json: true, prompt: "Respond using only JSON.", model: "gpt-3.5-turbo-1106")
    expect(convo.ask("How are you today?")).to eq({ "response" => "I'm just a program, so I don't have feelings, but I'm here and ready to help you!" })
  end

  context "functions" do
    it "converts functions passed as Hash objects to ChatgptRb::Function objects" do
      convo = described_class.new(functions: [
        {
          name: "get_current_weather",
          description: "",
          parameters: {
            type: "object",
            properties: {
              location: {
                type: "string",
                description: "",
              },
              unit: {
                type: "string",
                enum: ["celcius", "fahrenheit"],
              },
            },
            required: [:location]
          },
          implementation: ->() { nil },
        },
      ])
      expect(convo.functions["get_current_weather"].name).to eq("get_current_weather")
    end

    it "takes functions with no parameters" do
      convo = described_class.new(functions: [
        {
          name: "get_current_weather",
          description: "",
          implementation: ->() { nil },
        },
      ])
      expect(convo.functions["get_current_weather"].name).to eq("get_current_weather")
    end

    it "accepts functions passed as initialization arguments" do
      convo = described_class.new(functions: [
        ChatgptRb::Function.new(
          name: "get_current_weather",
          description: "",
          parameters: {},
          implementation: ->() { nil }
        ),
      ])
      expect(convo.functions["get_current_weather"].name).to eq("get_current_weather")
    end
  end

  it "can be asked things" do
    question = "How's it going?"
    mock_content = "As an AI, I don't have feelings or experiences, so I don't have a way to answer that question. However, I'm here to help you with any queries or tasks you have. How can I assist you today?"
    mock_response = {
      id: "chatcmpl-7a6l2cVOW7rY9YescrcLZnxImdMYN",
      object: "chat.completion",
      created: 1688840140,
      model: "gpt-3.5-turbo-0613",
      choices: [
        {
          index: 0,
          message: {
            role: "assistant",
            content: mock_content,
          },
          finish_reason: "stop",
        }
      ],
      usage: {
        prompt_tokens: 12,
        completion_tokens: 47,
        total_tokens: 59,
      },
    }
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(
        body: {
          model: "gpt-3.5-turbo",
          messages: [{ role: "user", content: question }],
          temperature: 0.7,
          max_tokens: 1024,
          top_p: 1.0,
          frequency_penalty: 0.0,
          presence_penalty: 0.0,
          stream: false,
        }.to_json
      )
      .to_return(headers: { "Content-Type" => "application/json" }, body: mock_response.to_json)
    convo = described_class.new
    response = convo.ask(question)
    expect(response).to eq(mock_content)
  end

  it "can inform conversations with a prompt" do
    prompt = "Act like a sullen teenager."
    question = "How's it going?"
    mock_content = "Ugh, whatever. Just another day in this boring, pointless existence."
    mock_response = {
      id: "chatcmpl-7a7nXVofBYrpGAlsL036pBvPA6PSk",
      object: "chat.completion",
      created: 1688844139,
      model: "gpt-3.5-turbo-0613",
      choices: [
        {
          index: 0,
          message: {
            role: "assistant",
            content: mock_content,
          },
          finish_reason: "stop",
        }
      ],
      usage: {
        prompt_tokens: 23,
        completion_tokens: 15,
        total_tokens: 38,
      },
    }

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(
        body: {
          model: "gpt-3.5-turbo",
          messages: [
            {role: "system", content: prompt},
            {role: "user", content: question},
          ],
          temperature: 0.7,
          max_tokens: 1024,
          top_p: 1.0,
          frequency_penalty: 0.0,
          presence_penalty: 0.0,
          stream: false
        }
      )
      .to_return(headers: { "Content-Type" => "application/json" }, body: mock_response.to_json)
    convo = described_class.new(prompt:)
    response = convo.ask(question)
    expect(response).to eq(mock_content)
    expect(convo.messages.first.fetch(:role)).to eq("system")
  end

  it "can use a function passed in a configuration block" do
    question = "What's the weather in Phoenix?"
    mock_content = "The current weather in Phoenix is sunny with a temperature of 22 degrees Celsius."
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(
        body: {
          model: "gpt-3.5-turbo",
          messages: [
            {
              role: "user",
              content: "What's the weather in Phoenix?",
            }
          ],
          temperature: 0.7,
          max_tokens: 1024,
          top_p: 1.0,
          frequency_penalty: 0.0,
          presence_penalty: 0.0,
          stream: false,
          tools: [
            {
              type: "function",
              function: {
                name: "get_current_weather",
                description: "Get the current weather for a given location",
                parameters: {
                  type: "object",
                  properties: {
                    location: {
                      type: "string",
                      description: "The location, eg Dallas, Texas",
                    },
                    unit: {
                      enum: ["celcius", "fahrenheit"],
                      type: "string",
                      description: "The units to return the temperature in",
                    },
                  },
                  required: ["location"],
                },
              },
            },
          ],
        },
      )
      .to_return(
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "chatcmpl-7a9EFC0JP3sgCAHG0bZCuUyHEaQUr",
          object: "chat.completion",
          created: 1688849639,
          model: "gpt-3.5-turbo-0613",
          choices: [
            {
              index: 0,
              message: {
                role: "assistant",
                content: nil,
                tool_calls: [
                  {
                    type: "function",
                    id: "1234",
                    function: {
                      name: "get_current_weather",
                      arguments: "{\n  \"location\": \"Phoenix\"\n}",
                    },
                  },
                ],
              },
              finish_reason: "function_call"
            }
          ],
          usage: {
            prompt_tokens: 86,
            completion_tokens: 16,
            total_tokens: 102
          }
        }.to_json)
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(
        body: {
          model: "gpt-3.5-turbo",
          messages: [
            {
              role: "user",
              content: "What's the weather in Phoenix?"
            },
            {
              role: "assistant",
              content: nil,
              tool_calls: [
                {
                  type: "function",
                  id: "1234",
                  function: {
                    name: "get_current_weather",
                    arguments: "{\n  \"location\": \"Phoenix\"\n}",
                  },
                },
              ],
            },
            {
              role: "tool",
              tool_call_id: "1234",
              name: "get_current_weather",
              content: "{\"temperature\":22,\"unit\":\"celcius\",\"description\":\"Sunny\"}",
            }
          ],
          temperature: 0.7,
          max_tokens: 1024,
          top_p: 1.0,
          frequency_penalty: 0.0,
          presence_penalty: 0.0,
          stream: false,
          tools: [
            {
              type: "function",
              function: {
                name: "get_current_weather",
                description: "Get the current weather for a given location",
                parameters: {
                  type: "object",
                  properties: {
                    location: {
                      type: "string",
                      description: "The location, eg Dallas, Texas",
                    },
                    unit: {
                      enum: ["celcius", "fahrenheit"],
                      type: "string",
                      description: "The units to return the temperature in",
                    }
                  },
                  required: ["location"],
                },
              },
            },
          ],
        }
      )
      .to_return(
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "chatcmpl-7a9EGbXw4Sxfc5DDFBTsZDoBAvvJE",
          object: "chat.completion",
          created: 1688849640,
          model: "gpt-3.5-turbo-0613",
          choices: [
            {
              index: 0,
              message: {
                role: "assistant",
                content: "The current weather in Phoenix is sunny with a temperature of 22 degrees Celsius."
              },
              finish_reason: "stop"
            }
          ],
          usage: {
            prompt_tokens: 127,
            completion_tokens: 17,
            total_tokens: 144
          },
        }.to_json,
      )

    convo = described_class.new do
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
    end
    response = convo.ask(question)
    expect(response).to eq(mock_content)
  end
end
