# frozen_string_literal: true

require "set"

module Gashadokuro
  class Lexer
    using Refinements

    class << self
      def call(selector)
        new.run(selector)
      end
    end

    TOKENS = {
      attribute: /\[\s*(?:(?<namespace>\*|[-\w\P{ASCII}]*)\|)?(?<name>[-\w\P{ASCII}]+)\s*(?:(?<operator>\W?=)\s*(?<value>.+?)\s*(\s(?<caseSensitive>[iIsS]))?\s*)?\]/,
      id: /#(?<name>[-\w\P{ASCII}]+)/,
      class: /\.(?<name>[-\w\P{ASCII}]+)/,
      comma: /\s*,\s*/,
      combinator: /\s*[\s>+~]\s*/,
      "pseudo-element": /::(?<name>[-\w\P{ASCII}]+)(?:\((?<argument>¶+)\))?/,
      "pseudo-class": /:(?<name>[-\w\P{ASCII}]+)(?:\((?<argument>¶+)\))?/,
      universal: /(?:(?<namespace>\*|[-\w\P{ASCII}]*)\|)?\*/,
      type: /(?:(?<namespace>\*|[-\w\P{ASCII}]*)\|)?(?<name>[-\w\P{ASCII}]+)/
    }.freeze
    TRIM_TOKENS = Set.new(%i[combinator comma])
    STRING_PATTERN = /(['"])([^\\\n]+?)\1/.freeze
    ESCAPE_PATTERN = /\\./.freeze

    def run(selector, grammar = TOKENS)
      return unless selector

      selector = selector.strip
      return [] if selector == ""

      replacements = []
      selector = selector.gsub(ESCAPE_PATTERN) do |value|
        replacements << { value: value, offset: Regexp.last_match.offset(0).first }
        "\uE000" * value.length
      end

      selector = selector.gsub(STRING_PATTERN) do |value|
        quote = Regexp.last_match[1]
        content = Regexp.last_match[2]
        replacements << { value: value, offset: Regexp.last_match.offset(0).first }
        dummy = "\uE001" * content.length
        "#{quote}#{dummy}#{quote}"
      end

      pos = 0
      while (offset = selector.index("(", pos))
        value = gobble_parens(selector, offset)
        replacements << { value: value, offset: offset }
        selector = "#{selector[0...offset]}#{"¶" * value.length}#{selector[(offset + value.length)..]}"
        pos = offset + value.length
      end

      tokens = tokenize_by(selector, grammar)

      changed_tokens = Set.new
      replacements.reverse_each do |replacement|
        offset = replacement[:offset]
        value = replacement[:value]

        tokens.each do |token|
          next unless token[:pos][0] <= offset && offset + value.length <= token[:pos][1]

          content = token[:content]
          token_offset = offset - token[:pos][0]
          token[:content] = "#{content[0...token_offset]}#{value}#{content[(token_offset + value.length)..]}"
          changed_tokens << token if token[:content] != content
        end
      end

      changed_tokens.each do |token|
        pattern = argument_pattern_by_type(token[:type])
        raise "Unknown token type: #{token[:type]}" unless pattern

        match = pattern.match(token[:content])
        raise "Unable to parse content for #{token[:type]}: #{token[:content]}" unless match

        token.merge!(match.named_captures.symbolize_keys.compact)
      end

      tokens
    end

    def gobble_parens(text, offset)
      nesting = 0
      result = ""
      while offset < text.length
        char = text[offset]
        case char
        when "("
          nesting += 1
        when ")"
          nesting -= 1
        end
        result += char
        return result if nesting.zero?

        offset += 1
      end
      result
    end

    def tokenize_by(text, grammar = TOKENS)
      return [] if text.empty?

      tokens = [text]
      grammar.each do |type, pattern|
        tokens.each_with_index do |token, i|
          next unless token.is_a?(String)

          match = pattern.match(token)
          next unless match

          args = []
          args << normalize_string(token[0...match.begin(0)])
          args << { type: type.to_sym, content: match[0], **match.named_captures.symbolize_keys.compact }
          args << normalize_string(token[(match.begin(0) + match[0].length)..])
          tokens[i, 1] = args.compact
        end
      end

      offset = 0
      tokens.each do |token|
        case token
        when String
          raise "Unexpected sequence #{token} found at index #{offset}"
        when Hash
          offset += token[:content].length
          token[:pos] = [offset - token[:content].length, offset]
          if TRIM_TOKENS.include?(token[:type])
            token[:content] = token[:content].strip.empty? ? " " : token[:content].strip
          end
        end
      end

      tokens
    end

    def normalize_string(str)
      return unless str && !str.empty?

      str
    end

    def argument_pattern_by_type(type)
      case type
      when :"pseudo-element", :"pseudo-class"
        argument_pattern = TOKENS[type].source.gsub("(?<argument>¶+)", "(?<argument>.+)")
        Regexp.new(argument_pattern, "u")
      else
        TOKENS[type]
      end
    end
  end
end
