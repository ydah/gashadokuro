# frozen_string_literal: true

require "set"

module Gashadokuro
  class Parser
    using Refinements

    TOKENS = {
      attribute: /\[\s*(?:(?<namespace>\*|[-\w\P{ASCII}]*)\|)?(?<name>[-\w\P{ASCII}]+)\s*(?:(?<operator>\W?=)\s*(?<value>.+?)\s*(\s(?<caseSensitive>[iIsS]))?\s*)?\]/u,
      id: /#(?<name>[-\w\P{ASCII}]+)/u,
      class: /\.(?<name>[-\w\P{ASCII}]+)/u,
      comma: /\s*,\s*/,
      combinator: /\s*[\s>+~]\s*/,
      "pseudo-element": /::(?<name>[-\w\P{ASCII}]+)(?:\((?<argument>¶+)\))?/u,
      "pseudo-class": /:(?<name>[-\w\P{ASCII}]+)(?:\((?<argument>¶+)\))?/u,
      universal: /(?:(?<namespace>\*|[-\w\P{ASCII}]*)\|)?\*/u,
      type: /(?:(?<namespace>\*|[-\w\P{ASCII}]*)\|)?(?<name>[-\w\P{ASCII}]+)/u
    }.freeze
    TRIM_TOKENS = Set.new(%i[combinator comma])
    RECURSIVE_PSEUDO_CLASSES = Set.new(["not", "is", "where", "has", "matches", "-moz-any", "-webkit-any", "nth-child", "nth-last-child"])
    RECURSIVE_PSEUDO_CLASSES_ARGS = {
      "nth-child" => /(?<index>[\dn+-]+)\s+of\s+(?<subtree>.+)/,
      "nth-last-child" => /(?<index>[\dn+-]+)\s+of\s+(?<subtree>.+)/
    }.freeze

    def argument_pattern_by_type(type)
      case type
      when :"pseudo-element", :"pseudo-class"
        argument_pattern = TOKENS[type].source.gsub("(?<argument>¶+)", "(?<argument>.+)")
        Regexp.new(argument_pattern, "u")
      else
        TOKENS[type]
      end
    end

    class << self
      def call(selector)
        new.tokenize(selector)
      end
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

    STRING_PATTERN = /(['"])([^\\\n]+?)\1/.freeze
    ESCAPE_PATTERN = /\\./.freeze

    def tokenize(selector, grammar = TOKENS)
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

    def nest_tokens(tokens, list: true)
      if list && tokens.find { |t| t[:type] == "comma" }
        selectors = []
        temp = []

        (0...tokens.length).each do |i|
          if tokens[i][:type] == "comma"
            raise "Incorrect comma at #{i}" if temp.empty?

            selectors.push(nestTokens(temp, list: false))
            temp.clear
          else
            temp.push(tokens[i])
          end
        end

        raise "Trailing comma" if temp.empty?

        selectors.push(nestTokens(temp, list: false))

        { type: "list", list: selectors }
      end

      (tokens.length - 1).downto(0) do |i|
        token = tokens[i]
        next unless token[:type] == "combinator"

        left = tokens[0...i]
        right = tokens[(i + 1)..]

        return {
          type: "complex",
          combinator: token[:content],
          left: nestTokens(left),
          right: nestTokens(right)
        }
      end

      case tokens.length
      when 0
        raise "Could not build AST."
      when 1
        tokens[0]
      else
        {
          type: "compound",
          list: tokens.clone # clone to avoid pointers messing up the AST
        }
      end
    end

    def flatten(node, parent = nil, &block)
      case node[:type]
      when "list"
        node[:list].each do |child|
          yield [child, node]
          flatten(child, node, &block)
        end
      when "complex"
        flatten(node[:left], node, &block)
        flatten(node[:right], node, &block)
      when "compound"
        node[:list].each { |token| yield [token, node] }
      else
        yield [node, parent]
      end
    end

    def walk(node, visit, parent = nil)
      return unless node

      flatten(node, parent).each do |token, ast|
        visit.call(token, ast)
      end
    end

    def parse(selector, recursive: true, list: true)
      tokens = tokenize(selector)
      return unless tokens

      ast = nest_tokens(tokens, list: list)

      return ast unless recursive

      flatten(ast).each do |token, _ast|
        next unless token.type == "pseudo-class" && token.argument
        next unless RECURSIVE_PSEUDO_CLASSES.include?(token.name)

        argument = token.argument
        child_arg = RECURSIVE_PSEUDO_CLASSES_ARGS[token.name]

        if child_arg
          match = child_arg.match(argument)
          next unless match

          token.merge!(match.named_captures.transform_keys(&:to_sym))
          argument = match[:subtree]
        end

        next unless argument

        token[:subtree] = parse(argument, recursive: true, list: true)
      end

      ast
    end

    def stringify(list_or_node)
      tokens = list_or_node.is_a?(Array) ? list_or_node : flatten(list_or_node).map(&:first)
      tokens.map(&:content).join
    end

    def specificity_to_number(specificity, base = nil)
      base ||= specificity.max + 1
      (specificity[0] * (base << 1)) + (specificity[1] * base) + specificity[2]
    end

    def specificity(selector)
      ast = selector.is_a?(String) ? parse(selector, { recursive: true }) : selector
      return [] if ast.nil?

      if ast.type == "list" && ast.key?("list")
        base = 10
        specificities = ast["list"].map do |v|
          sp = specificity(v)
          base = [base, *specificity(v)].max
          sp
        end
        numbers = specificities.map { |sp| specificity_to_number(sp, base) }
        specificities[numbers.index(numbers.max)]
      else
        ret = [0, 0, 0]
        flatten(ast).each do |(token, _)|
          case token["type"]
          when "id"
            ret[0] += 1
          when "class", "attribute"
            ret[1] += 1
          when "pseudo-element", "type"
            ret[2] += 1
          when "pseudo-class"
            next if token["name"] == "where"

            if !RECURSIVE_PSEUDO_CLASSES.include?(token["name"]) || !token.key?("subtree")
              ret[1] += 1
              next
            end
            sub = specificity(token["subtree"])
            sub.each_with_index { |s, i| ret[i] += s }
            # :nth-child() & :nth-last-child() add (0, 1, 0) to the specificity of their most complex selector
            ret[1] += 1 if token["name"] == "nth-child" || token["name"] == "nth-last-child"
          end
        end
        ret
      end
    end
  end
end
