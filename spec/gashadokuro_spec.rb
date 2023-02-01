# frozen_string_literal: true

RSpec.describe Gashadokuro do
  it "returns tokens" do
    p described_class.tokenize("#foo > .bar + div.k1.k2 [id='baz']:hello(2):not(:where(#yolo))::before")
  end
end
