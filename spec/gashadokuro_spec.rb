# frozen_string_literal: true

RSpec.describe Gashadokuro do
  it "returns tokens" do
    expect(described_class.tokenize("#foo > .bar + div.k1.k2 [id='baz']:hello(2):not(:where(#yolo))::before")).to match [
      {
        type: :id,
        content: "#foo",
        name: "foo",
        pos: [0, 4]
      },
      {
        type: :combinator,
        content: ">",
        pos: [4, 7]
      },
      {
        type: :class,
        content: ".bar",
        name: "bar",
        pos: [7, 11]
      },
      {
        type: :combinator,
        content: "+",
        pos: [11, 14]
      },
      {
        type: :type,
        content: "div",
        name: "div",
        pos: [14, 17]
      },
      {
        type: :class,
        content: ".k1",
        name: "k1",
        pos: [17, 20]
      },
      {
        type: :class,
        content: ".k2",
        name: "k2",
        pos: [20, 23]
      },
      {
        type: :combinator,
        content: " ",
        pos: [23, 24]
      },
      {
        type: :attribute,
        content: "[id='baz']",
        name: "id",
        operator: "=",
        value: "'baz'",
        pos: [24, 34]
      },
      {
        type: :"pseudo-class",
        content: ":hello(2)",
        name: "hello",
        argument: "2",
        pos: [34, 43]
      },
      {
        type: :"pseudo-class",
        content: ":not(:where(#yolo))",
        name: "not",
        argument: ":where(#yolo)",
        pos: [43, 62]
      },
      {
        type: :"pseudo-element",
        content: "::before",
        name: "before",
        pos: [62, 70]
      }
    ]
  end
end
