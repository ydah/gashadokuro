# frozen_string_literal: true

RSpec.describe Gashadokuro do
  it "returns tokens" do
    p described_class.tokenize("#foo")
    p described_class.tokenize("#foo > .bar")
  end
end
