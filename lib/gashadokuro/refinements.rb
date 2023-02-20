module Refinements
  refine Hash do
    def symbolize_keys
      self.transform_keys(&:to_sym)
    end
  end
end
