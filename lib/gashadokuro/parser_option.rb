# frozen_string_literal: true

module Gashadokuro
  class ParserOptions
    attr_accessor :recursive, :list

    def initialize(recursive: false, list: true)
      @recursive = recursive
      @list = list
    end
  end
end
