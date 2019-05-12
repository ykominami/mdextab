module Mdextab
  class Layer
    attr_accessor :return_from_nested_env, :cur_layer, :size

    def initialize(mes, output)
      @mes = mes
      @output = output
      @return_from_nested_env = false

      @layer_struct = Struct.new(:table, :star, :cur_state, :fname, :lineno)
      @cur_layer = nil
      @layers = []
    end

    def cur_state=(val)
      raise if val.class != Symbol
      @cur_layer.cur_state = val
    end

    def cur_state
      raise if @cur_layer.cur_state.class != Symbol
      @cur_layer.cur_state
    end

    def table
      @cur_layer.table
    end

    def table=(val)
      @cur_layer.table = val
    end

    def star=(val)
      @cur_layer.star = val
    end

    def star
      @cur_layer.star
    end

    def add_layer(fname, lineno, state=:START)
      new_layer = @layer_struct.new(nil, nil, nil, fname, lineno)
      @layers << new_layer
      @size = @layers.size
      puts "state.class=#{state.class}"
      raise if state.class != Symbol
      new_layer.cur_state = state
      if @cur_layer
        new_layer.star = @cur_layer.star
      else
        new_layer.star = false
      end
      @cur_layer = new_layer
    end

    def pop_prev_layer
      tmp_ = @layers.pop
      @size = @layers.size
      @cur_layer = @layers.last

      tmp_
    end

    def peek_prev_layer
      return nil unless @layers.size > 1

      @layers[@layers.size - 2]
    end

    def process_nested_table_start(token, lineno, fname)
      if table.tbody.nil?
        table.add_tbody(lineno)
      end
      @mes.outputDebug("B process_nested_table_start 1 @cur_layer.table=#{@cur_layer.table.object_id} token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} cur_state=#{@cur_layer.cur_state}")
      add_layer(fname, lineno, :OUT_OF_TABLE)
      @cur_layer.table = Table.new(token.opt[:lineno], @mes, token.opt[:attr])
      @mes.outputDebug("process_nested_table_start 3 token.kind=#{token.kind} cur_state=#{@cur_layer.cur_state}")
    end

    def process_table_end(token)
      prev_layer = peek_prev_layer
      if prev_layer
        process_table_end_for_prev_env(token, prev_layer)
      else
        @mes.outputDebug("1 - process_table_end cur_state=#{@cur_layer.cur_state} @return_from_nested_env~#{@return_from_nested_env}")
        @mes.excFileWrite(@o_fname) { @output.puts(@cur_layer.table.end) }
      end
    end

    def process_table_end_for_prev_env(token, prev_layer)
      tmp_table = @cur_layer.table
      pop_prev_layer
      @return_from_nested_env = true

      case @cur_layer.cur_state
      when :IN_TD
        prev_layer.table.td_append(tmp_table, prev_layer.star)
      when :IN_TD_NO_TBODY
        prev_layer.table.td_append(tmp_table, prev_layer.star)
      when :IN_TH
        prev_layer.table.th_append(tmp_table, prev_layer.star)
      when :IN_TH_NO_TBODY
        prev_layer.table.th_append(tmp_table, prev_layer.star)
      when :IN_TABLE
        if prev_layer.table.nil?
          @mes.outputDebug("In process_nested_table_env_for_prev_env: table=nil token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} cur_state=#{@cur_layer.cur_state}")
          raise
        end
        prev_layer.table.add(tmp_table)
      when :IN_TABLE_BODY
        prev_layer.table.add(tmp_table)
      when :START
        @mes.outputDebug("In process_nested_table_env_for_prev_env: table=nil token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} cur_state=#{@cur_layer.cur_state}")
        raise
      else
        v = prev_layer.cur_state || "nil"
        @mes.outputFatal("E100 cur_state=#{v}")
        @mes.outputFatal("table=#{prev_layer.table}")
        @mes.outputFatal("IllegalState(#{@cur_layer.cur_state} in process_table_end(#{token})")
        exit(@mes.ec("EXIT_CODE_TABLE_END"))
      end
    end

    def check_layers(fname)
      case @cur_layer.cur_state
      when :OUT_OF_TABLE
        if @layers.size > 1
          @mes.outputFatal("illeagal nested env after parsing|:OUT_OF_TABLE")
          @mes.outputFatal("@layers.size=#{@layers.size} :TABLE_START #{fname} #{table.lineno}")
          @layers.map {|x| @mes.outputDebug("== @layers.cur_state=#{x.cur_state} :TABLE_START #{fname} #{x.table.lineno}") }
          @mes.outputDebug("== table")
          @mes.outputInfo(table)
          exit(@mes.ec("EXIT_CODE_EXCEPTION"))
        end
      when :START
        if @layers.size > 1
          @mes.outputFatal("illeagal nested env after parsing|:START")
          @mes.outputFatal("@layers.size=#{@layers.size}")
          @layers.map {|x| @mes.outputError("== @layers.cur_state=#{x.cur_state} :TABLE_START #{fname} #{x.table.lineno}") }
          @mes.outputError("== table")
          @mes.outputError(table)
          exit(@mes.ec("EXIT_CODE_EXCEPTION"))
        end
      else
        @mes.outputFatal("illeagal state after parsing(@cur_layer.cur_state=#{@cur_layer.cur_state}|fname=#{fname}")
        @mes.outputFatal("@layers.size=#{@layers.size}")
        @mes.outputError("== cur_state=#{@cur_layer.cur_state}")
        @layers.map {|x| @mes.outputError("== @layers.cur_state=#{x.cur_state} #{fname}:#{x.table.lineno}") }
        @mes.outputError("")
        exit(@mes.ec("EXIT_CODE_ILLEAGAL_STATE"))
      end
    end

    def debug(nth, token)
      @mes.outputDebug("***#{nth}")
      @layers.each_with_index {|_x, ind| @mes.outputDebug("@layers[#{ind}]=#{@layers[ind]}") }
      @mes.outputDebug("******#{nth}")
      @mes.outputDebug("Layer#debug 1 token.kind=#{token.kind} @layer.cur_state=#{@cur_layer.cur_state}")
    end
  end
end
