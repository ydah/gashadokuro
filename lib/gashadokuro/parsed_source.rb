# frozen_string_literal: true

module Gashadokuro
  class ParsedSource
    def initialize(source)
      source.force_encoding(Encoding::UTF_8) unless source.encoding == Encoding::UTF_8

      @raw_source = source

      @tokens = Lexer.call(source)
    end
  end
end
