# frozen_string_literal: true

module Gashadokuro
  class BaseToken
    attr_accessor :type, :content, :pos

    def initialize(type:, content:, pos:)
      @type = type
      @content = content
      @pos = pos
    end
  end

  class CommaToken < BaseToken
    def initialize(content:, pos:)
      super(type: "comma", content: content, pos: pos)
    end
  end

  class CombinatorToken < BaseToken
    def initialize(content:, pos:)
      super(type: "combinator", content: content, pos: pos)
    end
  end

  class NamedToken < BaseToken
    attr_accessor :name

    def initialize(type:, content:, pos:, name:)
      super(type: type, content: content, pos: pos)
      @name = name
    end
  end

  class IdToken < NamedToken
    def initialize(content:, pos:, name:)
      super(type: "id", content: content, pos: pos, name: name)
    end
  end

  class ClassToken < NamedToken
    def initialize(content:, pos:, name:)
      super(type: "class", content: content, pos: pos, name: name)
    end
  end

  class PseudoElementToken < NamedToken
    attr_accessor :argument

    def initialize(content:, pos:, name:, argument: nil)
      super(type: "pseudo-element", content: content, pos: pos, name: name)
      @argument = argument
    end
  end

  class PseudoClassToken < NamedToken
    attr_accessor :argument, :subtree

    def initialize(content:, pos:, name:, argument: nil, subtree: nil)
      super(type: "pseudo-class", content: content, pos: pos, name: name)
      @argument = argument
      @subtree = subtree
    end
  end

  class NamespacedToken < BaseToken
    attr_accessor :namespace

    def initialize(type:, content:, pos:, namespace: nil)
      super(type: type, content: content, pos: pos)
      @namespace = namespace
    end
  end

  class UniversalToken < NamespacedToken
    attr_reader :type

    def initialize
      @type = "universal"
    end
  end

  class AttributeToken < NamespacedToken
    attr_reader :type, :operator, :value, :case_sensitive

    def initialize
      @type = "attribute"
      @operator = nil
      @value = nil
      @case_sensitive = nil
    end
  end

  class TypeToken < NamespacedToken
    attr_reader :type

    def initialize
      @type = "type"
    end
  end

  class UnknownToken < BaseToken
    def type
      raise "Invalid Token Type"
    end
  end

  class Complex
    attr_reader :type, :combinator, :right, :left

    def initialize
      @type = "complex"
      @combinator = ""
      @right = nil
      @left = nil
    end
  end

  class Compound
    attr_reader :type, :list

    def initialize
      @type = "compound"
      @list = []
    end
  end

  class List
    attr_reader :type, :list

    def initialize
      @type = "list"
      @list = []
    end
  end

  class AST
    attr_reader :type

    def initialize
      @type = ""
    end
  end

  class Token
    attr_reader :type

    def initialize
      @type = ""
    end
  end
end
