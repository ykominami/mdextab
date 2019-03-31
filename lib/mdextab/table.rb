require 'forwardable'

module Mdextab
  class Table
    extend Forwardable
    def_delegators :@tbody, :add_th, :add_td, :tdAppend, :thAppend, :add
    attr_reader :lineno

    def initialize(lineno, logger,attr=nil)
      @lineno = lineno
      @attr = attr
      @tbody = nil
      @logger = logger
    end

    def add_tbody(lineno)
      @tbody = Tbody.new(lineno, @logger)
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
          str_1 = %Q!<table #{@attr} lineno:#{@lineno}>! 
        else
          str_1 = %Q!<table #{@attr}>! 
        end
      else
        if debug
          str_1 = %Q!<table  lineno:#{@lineno}>!
        else
          str_1 = %Q!<table>!
        end
      end

      [str_1, @tbody.to_s, "</table>"].join("\n")
    end

  end
end
