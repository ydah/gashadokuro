# frozen_string_literal: true

module Refinements
  refine Hash do
    def symbolize_keys
      transform_keys(&:to_sym)
    end
  end
end
