module Mdextab
  class Tbody
    attr_reader :lineno

    def initialize(lineno, mes)
      @array = []
      @tr = nil
      @th = nil
      @td = nil
      @lineno = lineno
      @mes = mes
    end

    def add_th(lineno, content, nth, attr=nil, condense)
      if nth == 1
        @tr = Tr.new(lineno)
        @array << @tr
      end
      @th = Th.new(lineno, attr)
      @th.add(content, condense)
      @tr.add(@th)
    end

    def add_td(lineno, content, nth, attr=nil, condense)
      @mes.outputDebug( "content=#{content}|nth=#{nth}|attr=#{attr}" )
      if nth == 1
        @tr = Tr.new(lineno)
        @array << @tr
      end
      @td = Td.new(lineno,attr)
      @td.add(content, condense)
      @tr.add(@td)
    end

    def tdAppend(content, condense)
      @td.add(content, condense)
    end

    def thAppend(content, condense)
      @th.add(content, condense)
    end

    def add(cont)
      @array << cont
    end

    def end
      @tr = nil
    end

    def to_s
      ["<tbody>" , @array.map{|x| x.to_s} , "</tbody>"].join("\n")
    end
  end
end
