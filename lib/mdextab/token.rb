module Mdextab
  class Token
    attr_reader :kind, :opt

    def initialize(kind , opt={})
      @kind = kind
      @opt = opt
    end
  end
end

