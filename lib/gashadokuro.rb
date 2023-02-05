# frozen_string_literal: true

require "set"
require_relative "gashadokuro/version"

module Gashadokuro
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

  def gobble_parens(text, start)
    str = ""
    stack = []
    text[start...].chars.each.with_index do |char, idx|
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

            if (before = str[0...from + 1]) && !before.empty?
              args << before
            end

            args << {
              type: token,
              content: content
            }.merge(match.names.each_with_object({}) { |name, obj| obj[name.to_sym] = match[name] }).compact

            if (after = str[from + content.length + 1..]) && !after.empty?
              args << after
            end

            strarr[i, 1] = args
          end
        end
        i += 1
      end
    end

    normalize(strarr)
  end

  def normalize(strarr)
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
        groups = symbolize_keys(match.named_captures.compact)
        token.merge!(groups)
      end
    end
  end

  def symbolize_keys(hash)
    hash.transform_keys(&:to_sym)
  end
end
