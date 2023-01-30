# frozen_string_literal: true

require "set"
require_relative "gashadokuro/version"

module Gashadokuro
  TOKENS = {
    attribute: /\[\s*(?:(?<namespace>\*|[-\w]*)\|)?(?<name>[-\w]+)\s*(?:(?<operator>\W?=)\s*(?<value>.+?)\s*(\s(?<caseSensitive>[iIsS]))?\s*)?\]/,
    id: /#(?<name>(?:[-\w\u{0080}-\u{FFFF}]|\\.)+)/u,
    class: /\.(?<name>(?:[-\w\u{0080}-\u{FFFF}]|\\.)+)/u,
    comma: /\s*,\s*/,
    combinator: /\s*[\s>+~]\s*/,
    "pseudo-element": /::(?<name>[-\w\u{0080}-\u{FFFF}]+)(?:\((?<argument>¶+)\))?/u,
    "pseudo-class": /(?<name>[-\w\u{0080}-\u{FFFF}]+)(?:\((?<argument>¶+)\))?/u,
    universal: /(?:(\*|[-\w]+)\|)?\*/u,
    type: /(?:(?<namespace>\*|[-\w]*)\|)?(?<name>[-\w\u{0080}-\u{FFFF}]+)|\*/u
  }.freeze

  TOKENS_WITH_PARENS = Set.new(%w[pseudo-class pseudo-element])
  TOKENS_WITH_STRINGS = TOKENS_WITH_PARENS + Set.new(["attribute"])
  TRIM_TOKENS = Set.new(%w[combinator comma])

  TOKENS_FOR_RESTORE = {
    attribute: /\[\s*(?:(?<namespace>\*|[-\w]*)\|)?(?<name>[-\w]+)\s*(?:(?<operator>\W?=)\s*(?<value>.+?)\s*(\s(?<caseSensitive>[iIsS]))?\s*)?\]/,
    id: /#(?<name>(?:[-\w\u{0080}-\u{FFFF}]|\\.)+)/u,
    class: /\.(?<name>(?:[-\w\u{0080}-\u{FFFF}]|\\.)+)/u,
    comma: /\s*,\s*/,
    combinator: /\s*[\s>+~]\s*/,
    "pseudo-element": /::(?<name>[-\w\u{0080}-\u{FFFF}]+)(?:\((.+?)\))?/u,
    "pseudo-class": /(?<name>[-\w\u{0080}-\u{FFFF}]+)(?:\((.+)\))?/u,
    universal: /(?:(\*|[-\w]+)\|)?\*/u,
    type: /(?:(?<namespace>\*|[-\w]*)\|)?(?<name>[-\w\u{0080}-\u{FFFF}]+)|\*/u
  }.freeze

  module_function

  def tokenize(selector)
    return unless selector

    selector = selector.strip

    strings = []
    selector = extract_string_literals(selector, strings)
    parens = []
    selector = extract_parens(selector, parens)

    tokens = tokenize_by(selector, TOKENS)

    restore_nested(tokens, parens, /\(¶+\)/, TOKENS_WITH_PARENS)
    restore_nested(tokens, strings, /(['"])§+?\1/, TOKENS_WITH_STRINGS)

    tokens
  end

  def extract_string_literals(selector, strings)
    selector.gsub(/(['"])((?:\\\1|.)+?)\1/) do |str|
      strings << { str: str, start: Regexp.last_match.begin(0) }
      quote = Regexp.last_match(1)
      quote + ("§" * (str.length - 2)) + quote
    end
  end

  def extract_parens(selector, parens)
    offset = 0
    while (start = selector.index("(", offset))
      str = gobble_parens(selector, start)
      parens << { str: str, start: start }
      selector = selector.sub(str, "(#{"¶" * (str.length - 2)})")
      offset = start + str.length
    end
    selector
  end

  def gobble_parens(text, i)
    str = []
    stack = []
    (i...text.length).each do |j|
      char = text[j]
      case char
      when "("
        stack.push(char)
      when ")"
        raise "Closing paren without opening paren at #{j}" if stack.empty?

        stack.pop
      end
      str << char
      break if stack.empty?
    end
    raise "Opening paren without closing paren" unless stack.empty?

    str.join
  end

  def tokenize_by(text, grammar)
    return [] unless text

    strarr = [text]
    grammar.each do |token, pattern|
      i = 0
      while i < strarr.length
        str = strarr[i]
        if str.is_a?(String)
          pattern.match(str) do |match|
            from = match.begin(0) - 1
            args = []
            content = match[0]

            before = str.slice(0, from + 1)
            args << before unless before.empty?

            args << {
              type: token,
              content: content,
              groups: match.names.each_with_object({}) { |name, obj| obj[name] = match[name] }
            }

            after = str.slice(from + content.length + 1)
            if after
              args << after unless after.empty?
            end

            strarr[i, 1] = args
          end
        end
        i += 1
      end
    end

    offset = 0
    strarr.each do |token|
      next unless token

      length = token.length || token[:content].length

      if token.is_a?(Hash)
        token[:pos] = [offset, offset + length]
        if TRIM_TOKENS.include?(token[:type])
          token[:content] = token[:content].strip.empty? ? " " : token[:content].strip
        end
      end

      offset += length
    end

    strarr
  end

  def restore_nested(tokens, strings, regex, types)
    strings.reverse_each do |str|
      tokens.each do |token|
        next unless token
        next unless token.is_a?(Hash)
        next unless types.include?(token[:type]) &&
                    token[:pos][0] < str[:start] &&
                    str[:start] < token[:pos][1]

        content = token[:content]
        token[:content] = token[:content].gsub(regex, str[:str])
        next unless content != token[:content]

        TOKENS_FOR_RESTORE[token[:type]].last_index = 0
        match = TOKENS_FOR_RESTORE[token[:type]].match(token[:content])
        groups = match.named_captures
        token.merge!(groups)
      end
    end
  end
end
