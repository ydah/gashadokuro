# frozen_string_literal: true

RSpec.describe Gashadokuro::Lexer do
  describe ".call" do
    context "when selector is nil" do
      it "returns nil" do
        expect(described_class.call(nil)).to be_nil
      end
    end

    context "when selector is empty" do
      it "returns empty array" do
        expect(described_class.call("")).to match []
      end
    end

    context "when selector is a single element selector" do
      it "returns tokens" do
        expect(described_class.call("div")).to match [{ type: :type, content: "div", name: "div", pos: [0, 3] }]
        expect(described_class.call("section")).to match [{ type: :type, content: "section", name: "section", pos: [0, 7] }]
      end
    end

    context "when selector is a single class selector" do
      it "returns tokens" do
        expect(described_class.call(".foo")).to match [{ type: :class, content: ".foo", name: "foo", pos: [0, 4] }]
        expect(described_class.call(".foo.bar")).to match [{ type: :class, content: ".foo", name: "foo", pos: [0, 4] }, { type: :class, content: ".bar", name: "bar", pos: [4, 8] }]
      end
    end

    context "when selector is a single id selector" do
      it "returns tokens" do
        expect(described_class.call("#foo")).to match [{ type: :id, content: "#foo", name: "foo", pos: [0, 4] }]
        expect(described_class.call("#foo#bar")).to match [{ type: :id, content: "#foo", name: "foo", pos: [0, 4] }, { type: :id, content: "#bar", name: "bar", pos: [4, 8] }]
      end
    end

    context "when selector is a single attribute selector" do
      it "returns tokens" do
        expect(described_class.call("[foo]")).to match [{ type: :attribute, content: "[foo]", name: "foo", pos: [0, 5] }]
        expect(described_class.call("[foo='bar']")).to match [{ type: :attribute, content: "[foo='bar']", name: "foo", operator: "=", value: "'bar'", pos: [0, 11] }]
        expect(described_class.call("[foo~='bar']")).to match [{ type: :attribute, content: "[foo~='bar']", name: "foo", operator: "~=", value: "'bar'", pos: [0, 12] }]
        expect(described_class.call("[foo|='bar']")).to match [{ type: :attribute, content: "[foo|='bar']", name: "foo", operator: "|=", value: "'bar'", pos: [0, 12] }]
        expect(described_class.call("[foo^='bar']")).to match [{ type: :attribute, content: "[foo^='bar']", name: "foo", operator: "^=", value: "'bar'", pos: [0, 12] }]
        expect(described_class.call("[foo$='bar']")).to match [{ type: :attribute, content: "[foo$='bar']", name: "foo", operator: "$=", value: "'bar'", pos: [0, 12] }]
        expect(described_class.call("[foo*='bar']")).to match [{ type: :attribute, content: "[foo*='bar']", name: "foo", operator: "*=", value: "'bar'", pos: [0, 12] }]
      end
    end

    context "when selector are multiple attribute selectors" do
      it "returns tokens" do
        expect(described_class.call("[foo='bar'][baz='qux']")).to match [
          { type: :attribute, content: "[foo='bar']", name: "foo", operator: "=", value: "'bar'", pos: [0, 11] },
          { type: :attribute, content: "[baz='qux']", name: "baz", operator: "=", value: "'qux'", pos: [11, 22] }
        ]
        expect(described_class.call("[foo='bar'][baz='qux'][quux='quuz']")).to match [
          { type: :attribute, content: "[foo='bar']", name: "foo", operator: "=", value: "'bar'", pos: [0, 11] },
          { type: :attribute, content: "[baz='qux']", name: "baz", operator: "=", value: "'qux'", pos: [11, 22] },
          { type: :attribute, content: "[quux='quuz']", name: "quux", operator: "=", value: "'quuz'", pos: [22, 35] }
        ]
      end
    end

    context "when selector is a single pseudo-class selector" do
      it "returns tokens" do
        expect(described_class.call(":foo")).to match [{ type: :"pseudo-class", content: ":foo", name: "foo", pos: [0, 4] }]
        expect(described_class.call(":foo(2)")).to match [{ type: :"pseudo-class", content: ":foo(2)", name: "foo", argument: "2", pos: [0, 7] }]
        expect(described_class.call(":foo(bar)")).to match [{ type: :"pseudo-class", content: ":foo(bar)", name: "foo", argument: "bar", pos: [0, 9] }]
        expect(described_class.call(":foo(bar, baz)")).to match [{ type: :"pseudo-class", content: ":foo(bar, baz)", name: "foo", argument: "bar, baz", pos: [0, 14] }]
      end
    end

    context "when selector is a single pseudo-element selector" do
      it "returns tokens" do
        expect(described_class.call("::foo")).to match [{ type: :"pseudo-element", content: "::foo", name: "foo", pos: [0, 5] }]
        expect(described_class.call("::foo(2)")).to match [{ type: :"pseudo-element", content: "::foo(2)", name: "foo", argument: "2", pos: [0, 8] }]
        expect(described_class.call("::foo(bar)")).to match [{ type: :"pseudo-element", content: "::foo(bar)", name: "foo", argument: "bar", pos: [0, 10] }]
        expect(described_class.call("::foo(bar, baz)")).to match [{ type: :"pseudo-element", content: "::foo(bar, baz)", name: "foo", argument: "bar, baz", pos: [0, 15] }]
      end
    end

    context "when selector are multiple selectors" do
      it "returns tokens" do
        expect(described_class.call("#foo > .bar + div.k1.k2 [id='baz']:hello(2):not(:where(#yolo))::before")).to match [
          { type: :id, content: "#foo", name: "foo", pos: [0, 4] },
          { type: :combinator, content: ">", pos: [4, 7] },
          { type: :class, content: ".bar", name: "bar", pos: [7, 11] },
          { type: :combinator, content: "+", pos: [11, 14] },
          { type: :type, content: "div", name: "div", pos: [14, 17] },
          { type: :class, content: ".k1", name: "k1", pos: [17, 20] },
          { type: :class, content: ".k2", name: "k2", pos: [20, 23] },
          { type: :combinator, content: " ", pos: [23, 24] },
          { type: :attribute, content: "[id='baz']", name: "id", operator: "=", value: "'baz'", pos: [24, 34] },
          { type: :"pseudo-class", content: ":hello(2)", name: "hello", argument: "2", pos: [34, 43] },
          { type: :"pseudo-class", content: ":not(:where(#yolo))", name: "not", argument: ":where(#yolo)", pos: [43, 62] },
          { type: :"pseudo-element", content: "::before", name: "before", pos: [62, 70] }
        ]
      end
    end
  end
end
