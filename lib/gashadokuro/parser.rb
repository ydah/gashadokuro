# frozen_string_literal: true

require "set"

module Gashadokuro
  class Parser
    using Refinements

    TOKENS = {
      attribute: /\[\s*(?:(?<namespace>\*|[-\w]*)\|)?(?<name>[-\w\u{0080}-\u{FFFF}]+)\s*(?:(?<operator>\W?=)\s*(?<value>.+?)\s*(\s(?<caseSensitive>[iIsS]))?\s*)?\]/u,
      id: /#(?<name>(?:[-\w\u{0080}-\u{FFFF}]|\\.)+)/u,
      class: /\.(?<name>(?:[-\w\u{0080}-\u{FFFF}]|\\.)+)/u,
      comma: /\s*,\s*/,
      combinator: /\s*[\s>+~]\s*/,
      "pseudo-element": /::(?<name>[-\w\u{0080}-\u{FFFF}]+)(?:\((?<argument>¶+)\))?/u,
      "pseudo-class": /:(?<name>[-\w\u{0080}-\u{FFFF}]+)(?:\((?<argument>¶+)\))?/u,
      universal: /(?:(?<namespace>\*|[-\w]*)\|)?\*/u,
      type: /(?:(?<namespace>\*|[-\w]*)\|)?(?<name>[-\w\u{0080}-\u{FFFF}]+)|\*/u
    }.freeze

    TOKENS_WITH_PARENS = Set.new(%i[pseudo-class pseudo-element])
    TOKENS_WITH_STRINGS = TOKENS_WITH_PARENS + Set.new(%i[attribute])
    TRIM_TOKENS = Set.new(%i[combinator comma])

    TOKENS_FOR_RESTORE = {
      attribute: /\[\s*(?:(?<namespace>\*|[-\w]*)\|)?(?<name>[-\w\u{0080}-\u{FFFF}]+)\s*(?:(?<operator>\W?=)\s*(?<value>.+?)\s*(\s(?<caseSensitive>[iIsS]))?\s*)?\]/u,
      id: /#(?<name>(?:[-\w\u{0080}-\u{FFFF}]|\\.)+)/u,
      class: /\.(?<name>(?:[-\w\u{0080}-\u{FFFF}]|\\.)+)/u,
      comma: /\s*,\s*/,
      combinator: /\s*[\s>+~]\s*/,
      "pseudo-element": /::(?<name>[-\w\u{0080}-\u{FFFF}]+)(?:\((?<argument>.+?)\))?/u,
      "pseudo-class": /:(?<name>[-\w\u{0080}-\u{FFFF}]+)(?:\((?<argument>.+)\))?/u,
      universal: /(?:(?<namespace>\*|[-\w]*)\|)?\*/u,
      type: /(?:(?<namespace>\*|[-\w]*)\|)?(?<name>[-\w\u{0080}-\u{FFFF}]+)|\*/u
    }.freeze

    class << self
      def call(selector)
        new(selector).call
      end
    end

    def initialize(selector)
      @selector = selector.strip
      @strings = @parens = []
    end

    def call
      return unless @selector

      extract_string_literals!
      extract_parens!
      tokens = tokenize_by(TOKENS)
      restore_nested(tokens, @parens, /\(¶+\)/, TOKENS_WITH_PARENS)
      restore_nested(tokens, @strings, /(['"])§+?\1/, TOKENS_WITH_STRINGS)
      tokens
    end

    private

    def extract_string_literals!
      @selector.gsub!(/(['"])((?:\\\1|.)+?)\1/) do |str|
        @strings << { str: str, start: Regexp.last_match.begin(0) }
        quote = Regexp.last_match(1)
        quote + ("§" * (str.length - 2)) + quote
      end
    end

    def extract_parens!
      offset = 0
      while (start = @selector.index("(", offset))
        str = gobble_parens(start)
        @parens << { str: str, start: start }
        @selector = @selector.sub(str, "(#{"¶" * (str.length - 2)})")
        offset = start + str.length
      end
    end

    def gobble_parens(start)
      str = ""
      stack = []
      @selector[start...].chars.each.with_index do |char, idx|
        case char
        when "("
          stack.push(char)
        when ")"
          raise "Closing paren without opening paren at #{idx}" if stack.empty?

          stack.pop
        end
        str += char
        break if stack.empty?
      end
      raise "Opening paren without closing paren" unless stack.empty?

      str
    end

    def tokenize_by(grammar)
      return [] unless @selector

      strarr = [@selector]
      grammar.each do |token, pattern|
        i = 0
        while i < strarr.length
          str = strarr[i]
          if str.is_a?(String)
            pattern.match(str) do |match|
              args = []
              args << normalize_string(str[0...match.begin(0)])
              args << { type: token, content: match[0] }
                      .merge(match.names.each_with_object({}) { |name, obj| obj[name.to_sym] = match[name] })
                      .compact
              args << normalize_string(str[match.begin(0) + match[0].length..])
              strarr[i, 1] = args.compact
            end
          end
          i += 1
        end
      end

      normalize_token(strarr)
    end

    def normalize_string(str)
      return unless str && !str.empty?

      str
    end

    def normalize_token(strarr)
      offset = 0
      strarr.each do |token|
        length = token.is_a?(String) ? token.length : token[:content].length
        if token.is_a?(Hash)
          token[:pos] = [offset, offset + length]
          token[:content] = normalize_content(token[:content]) if TRIM_TOKENS.include?(token[:type])
        end
        offset += length
      end
    end

    def normalize_content(content)
      content.strip.empty? ? " " : content.strip
    end

    def restore_nested(tokens, strings, regex, types)
      strings.each do |str|
        tokens.each do |token|
          next unless types.include?(token[:type]) &&
                      token[:pos][0] < str[:start] &&
                      str[:start] < token[:pos][1]

          content = token[:content]
          token[:content] = token[:content].gsub(regex, str[:str])
          next unless content != token[:content]

          match = TOKENS_FOR_RESTORE[token[:type]].match(token[:content])
          groups = match.named_captures.symbolize_keys.compact
          token.merge!(groups)
        end
      end
    end
  end
end
