module Mdextab
  class Tr
    def initialize(lineno)
      @lineno = lineno
      @array = []
    end

    def add(cont)
      @array << cont
    end

    def to_s
      ["<tr>", @array.map(&:to_s), "</tr>"].join("\n")
    end
  end
end
