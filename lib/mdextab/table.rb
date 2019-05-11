require "forwardable"

module Mdextab
  class Table
    extend Forwardable
    def_delegators :@tbody, :add_th, :add_td, :td_append, :th_append, :add
    attr_reader :lineno, :tbody

    def initialize(lineno, mes, attr=nil)
      @lineno = lineno
      @attr = attr
      @tbody = nil
      @mes = mes
    end

    def add_tbody(lineno)
      @tbody = Tbody.new(lineno, @mes)
    end

    def tbody_end
      @tbody.end
    end

    def end
      table_end
    end

    def table_end
      to_s
    end

    def to_s(debug=false)
      if @attr
        if debug
          str = %Q(<table #{@attr} lineno:#{@lineno}>)
        else
          str = %Q(<table #{@attr}>)
        end
      elsif debug
        str = %Q(<table  lineno:#{@lineno}>)
      else
        str = %Q(<table>)
      end

      [str, @tbody.to_s, "</table>"].join("\n")
    end
  end
end
