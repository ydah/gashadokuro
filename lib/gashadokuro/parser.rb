# frozen_string_literal: true


module Gashadokuro
  class Parser
    RECURSIVE_PSEUDO_CLASSES = Set.new(["not", "is", "where", "has", "matches", "-moz-any", "-webkit-any", "nth-child", "nth-last-child"])
    RECURSIVE_PSEUDO_CLASSES_ARGS = {
      "nth-child" => /(?<index>[\dn+-]+)\s+of\s+(?<subtree>.+)/,
      "nth-last-child" => /(?<index>[\dn+-]+)\s+of\s+(?<subtree>.+)/
    }.freeze

    class << self
      def call(tokens)
        new.parse(tokens)
      end
    end

    def parse(tokens, recursive: true, list: true)
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

    def nest_tokens(tokens, list: true)
      if list && tokens.find { |t| t[:type] == "comma" }
        selectors = []
        temp = []

        (0...tokens.length).each do |i|
          if tokens[i][:type] == "comma"
            raise "Incorrect comma at #{i}" if temp.empty?

            selectors.push(nest_tokens(temp, list: false))
            temp.clear
          else
            temp.push(tokens[i])
          end
        end

        raise "Trailing comma" if temp.empty?

        selectors.push(nest_tokens(temp, list: false))

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
          left: nest_tokens(left),
          right: nest_tokens(right)
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
