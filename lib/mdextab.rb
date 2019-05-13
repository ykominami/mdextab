module Mdextab
  class Error < StandardError; end

  class Mdextab
    require "mdextab/version"
    require "mdextab/token"
    require "mdextab/table"
    require "mdextab/tbody"
    require "mdextab/td"
    require "mdextab/th"
    require "mdextab/token"
    require "mdextab/tr"
    require "mdextab/makemdtab"
    require "mdextab/layer"
    require "messagex/loggerx"
    require "filex"

    require "byebug"

    def initialize(opt, fname, o_fname, mes=nil)
      @fname = fname
      @o_fname = o_fname

      @mes = mes
      unless @mes
        @mes = Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, opt["debug"])
        @mes.register_ecx
      end

      @mes.add_exitcode("EXIT_CODE_NEXT_STATE")
      @mes.add_exitcode("EXIT_CODE_NIL")
      @mes.add_exitcode("EXIT_CODE_EXCEPTION")
      @mes.add_exitcode("EXIT_CODE_TABLE_END")
      @mes.add_exitcode("EXIT_CODE_UNKNOWN")
      @mes.add_exitcode("EXIT_CODE_ILLEAGAL_STATE")

      Filex::Filex.setup(@mes)

      unless File.exist?(fname)
        @mes.output_fatal("Can't find #{fname}")
        exit(@mes.ec("EXIT_CODE_CANNOT_FIND_FILE"))
      end

      dir = File.dirname(o_fname)
      if dir != "."
        @mes.exc_make_directory(dir) { FileUtils.mkdir_p(dir) }
      end
      @mes.exc_file_write(o_fname) { @output = File.open(o_fname, "w") }

      @token_op = Token.new(@mes)
      @layer = Layer.new(@mes, @output)

      set_state
    end

    def set_state
      @states = {
        START: { TABLE_START: :IN_TABLE, ELSE: :OUT_OF_TABLE, STAR_START: :START, STAR_END: :START },
        OUT_OF_TABLE: { TABLE_START: :IN_TABLE, ELSE: :OUT_OF_TABLE, STAR_START: :OUT_OF_TABLE, STAR_END: :OUT_OF_TABLE, TD: :OUT_OF_TABLE },
        IN_TABLE: { TBODY_START: :IN_TABLE_BODY, TABLE_END: :OUT_OF_TABLE, ELSE: :IN_TABLE, TD: :IN_TD_NO_TBODY, TH: :IN_TH_NO_TBODY, TABLE_START: :IN_TABLE, STAR_START: :IN_TABLE, STAR_END: :IN_TABLE },
        IN_TABLE_BODY: { TH: :IN_TH, TD: :IN_TD, ELSE: :IN_TABLE_BODY, TABLE_START: :IN_TABLE_BODY, TBODY_END: :IN_TABLE, TABLE_END: :OUT_OF_TABLE, STAR_START: :IN_TABLE_BODY, STAR_END: :IN_TABLE_BODY },
        IN_TH: { ELSE: :IN_TH, TH: :IN_TH, TD: :IN_TD, TABLE_START: :IN_TH, STAR_START: :IN_TH, STAR_END: :IN_TH },
        IN_TH_NO_TBODY: { ELSE: :IN_TH_NO_TBODY, TH: :IN_TH_NO_TBODY, TD: :IN_TD_NO_TBODY, TABLE_START: :IN_TH_NO_TBODY, STAR_START: :IN_TH_NO_TBODY, STAR_END: :IN_TH_NO_TBODY },
        IN_TD: { ELSE: :IN_TD, TH: :IN_TH, TD: :IN_TD, TBODY_END: :IN_TABLE, TABLE_START: :IN_TD, STAR_START: :IN_TD, START_END: :IN_TD },
        IN_TD_NO_TBODY: { ELSE: :IN_TD_NO_TBODY, TH: :IN_TH_NO_TBODY, TD: :IN_TD_NO_TBODY, TABLE_START: :IN_TD_NO_TBODY, TABLE_END: :OUT_OF_TABLE, TBODY_END: :IN_TABLE, STAR_START: :IN_TD_NO_TBODY, STAR_END: :IN_TD_NO_TBODY },
      }
    end

    def parse(hash)
      lineno = 0
      @layer.add_layer(@fname, lineno)
      Filex::Filex.check_and_expand_file_lines(@fname, hash, @mes).each do |line|
        lineno += 1
        token = @token_op.get_token(line, lineno)
        kind = token.kind

        @mes.output_debug("layer.size=#{@layer.size}")
        @mes.output_debug("token.kind=#{kind}")
        @mes.output_debug(%Q!(source)#{lineno}:#{line}!)
        if @layer.cur_state.nil?
          @mes.output_error("(script)#{__LINE__}| @layer.cur_state=nil")
        else
          @mes.output_debug("(script)#{__LINE__}| @layer.cur_state=#{@layer.cur_state}")
        end
        #        debug_envs(5, token)

        @layer.cur_state = process_one_line(@layer.cur_state, token, line, lineno, @fname)
        unless @layer.cur_state
          @mes.output_fatal("process_one_line returns nil")
          exit(@mes.ec("EXIT_CODE_NEXT_STATE"))
        end

        @mes.output_debug("NEXT kind=#{kind} @layer.cur_state=#{@layer.cur_state}")
        @mes.output_debug("-----")
      end
      @layer.check_layers(@fname)
    end

    def parse2(yamlfname)
      hs = Filex::Filex.check_and_load_yamlfile(yamlfname, @mes)
      parse(hs)
    end

    def get_next_state(token, line, lineno, fname)
      kind = token.kind
      @mes.output_debug("#{__LINE__}|@layer.cur_state=#{@layer.cur_state} #{@layer.cur_state.class}")
      state_level1 = @states[@layer.cur_state]
      if state_level1.nil?
        @mes.output_error(%Q(token.kind=#{kind} | cur_state=#{@layer.cur_state}))
        @mes.output_error("=== state_level1 == nil")
        @mes.output_fatal("Next State is nil")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_NIL"))
      else
        @mes.output_debug("state_level1=#{state_level1}")
      end
      @mes.output_debug("#{__LINE__}|kind=#{kind}")

      begin
        next_state = state_level1[kind]
        @mes.output_debug("#{__LINE__}|next_state=#{next_state}")
      rescue StandardError
        @mes.output_fatal("@layer.cur_state=#{@layer.cur_state}")
        @mes.output_fatal("kind=#{kind}")
        @mes.output_fatal("next_state=#{next_state}")
        exit(@mes.ec("EXIT_CODE_EXCEPTION"))
      end
      @mes.output_debug("#{__LINE__}|next_state=#{next_state}")
      next_state
    end

    def output_in_else(str)
      if @layer.star
        if str.match?(/^\s*$/)
          @mes.output_debug("InElse do nothing")
        else
          @mes.exc_file_write(@o_fname) { @output.puts(str) }
        end
      else
        @mes.exc_file_write(@o_fname) { @output.puts(str) }
      end
    end

    def table_th_append_in_else(str)
      if @layer.star
        if str.match?(/^\s*$/)
          @mes.output_debug("ThAppend InElse")
        else
          @layer.table.th_append(str, @layer.star)
        end
      else
        @layer.table.th_append(str, @layer.star)
      end
    end

    def table_td_append_in_else(str)
      if @layer.star
        if str.match?(/^\s*$/)
          @mes.output_debug("TdAppend InElse")
        else
          @layer.table.td_append(str, @layer.star)
        end
      else
        @layer.table.td_append(str, @layer.star)
      end
    end

    def process_one_line_for_start(token, line, lineno, fname)
      case token.kind
      when :TABLE_START
        @layer.table = Table.new(lineno, @mes, token.opt[:attr])
      when :ELSE
        # threw
        output_in_else(token.opt[:content])
      when :STAR_START
        @layer.star = true
        output_in_else("*" + token.opt[:content])
      when :STAR_END
        @layer.star = false
        output_in_else("*" + token.opt[:content])
        output_in_else(token.opt[:content])
      else
        @mes.output_fatal("In :START unknown tag=(#{token.kind}) in process_one_line_for_start")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_out_of_table(token, line, lineno, fname)
      case token.kind
      when :TABLE_START
        @layer.table = Table.new(lineno, @mes, token.opt[:attr])
      when :ELSE
        output_in_else(token.opt[:content])
      when :STAR_START
        @layer.star = true
        output_in_else("*" + token.opt[:content])
      when :STAR_END
        @layer.star = false
        output_in_else("*" + token.opt[:content])
        output_in_else(token.opt[:content])
      when :TD
        # treat as :ELSE
        output_in_else(":" + token.opt[:content])
      else
        @mes.output_fatal("In :OUT_OF_TABLE unknown tag=(#{token.kind}) in process_one_line_for_out_of_table")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        @layer.check_layers(@fname)
      end
    end

    def process_one_line_for_table_end(token)
      @layer.process_table_end(token)
      return if @layer.return_from_nested_env

      @mes.output_debug("1 - process_one_line_table_end cur_state=#{@layer.cur_state} @return_from_nested_env~#{@layer.return_from_nested_env}")
      @mes.exc_file_write(@o_fname) { @output.puts(@layer.table.end) }
    end

    def process_one_line_for_in_table(token, line, lineno, fname)
      case token.kind
      when :TBODY_START
        @layer.table.add_tbody(lineno)
      when :TABLE_END
        process_one_line_for_table_end(token)
      when :ELSE
        output_in_else(token.opt[:content])
      when :TD
        @mes.output_debug(token)
        @layer.table.add_tbody(lineno)
        @layer.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TH
        @layer.table.add_tbody(lineno)
        @layer.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TABLE_START
        @layer.process_nested_table_start(token, lineno, fname)
      when :STAR_START
        @layer.star = true
        output_in_else("*" + token.opt[:content])
      when :STAR_END
        @layer.star = false
        output_in_else("*" + token.opt[:content])
      else
        @mes.output_fatal("In :IN_TABLE unknown tag=(#{token.kind}) in process_one_line_for_in_table")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_table_body(token, line, lineno, fname)
      case token.kind
      when :TH
        @layer.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TD
        @mes.output_debug(token)
        @layer.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :ELSE
        output_in_else(token.opt[:content])
      when :TABLE_START
        @layer.process_nested_table_start(token, lineno, fname)
      when :TBODY_END
        true #  don't call process_table_end(token)
      when :TABLE_END
        process_one_line_for_table_end(token)
      when :STAR_START
        @layer.star = true
        output_in_else("*" + token.opt[:content])
      when :STAR_END
        @layer.star = false
        output_in_else("*" + token.opt[:content])
      else
        @mes.output_fatal("In :IN_TABLE_BODY unknown tag=(#{token.kind}) in process_one_line_for_in_table_body")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_th(token, line, lineno, fname)
      case token.kind
      when :ELSE
        table_th_append_in_else(token.opt[:content])
      when :TH
        @layer.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TD
        @layer.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TABLE_START
        @layer.process_nested_table_start(token, lineno, fname)
      when :STAR_START
        @layer.star = true
        table_th_append_in_else("*" + token.opt[:content])
      when :STAR_END
        @layer.star = false
        table_th_append_in_else("*" + token.opt[:content])
      else
        @mes.output_fatal("In :IN_TH unknown tag=(#{token.kind}) in process_one_line_for_in_th")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_th_no_tbody(token, line, lineno, fname)
      case token.kind
      when :ELSE
        table_th_append_in_else(token.opt[:content])
      when :TH
        @layer.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TD
        @layer.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TABLE_START
        @layer.process_nested_table_start(token, lineno, fname)
      when :STAR_START
        @layer.star = true
        table_th_append_in_else("*" + token.opt[:content])
      when :STAR_END
        @layer.star = false
        table_th_append_in_else("*" + token.opt[:content])
      else
        @mes.output_fatal("In :IN_TH_NO_TBODY unknown tag=(#{token.kind}) in process_one_line_for_in_th_no_tbody")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_td(token, line, lineno, fname)
      case token.kind
      when :ELSE
        table_td_append_in_else(token.opt[:content])
      when :TH
        @layer.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TD
        @layer.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TBODY_END
        @layer.table.tbody_end
      when :TABLE_START
        @layer.process_nested_table_start(token, lineno, fname)
      when :STAR_START
        @layer.star = true
        table_td_append_in_else("*" + token.opt[:content])
      when :STAR_END
        @layer.star = false
        table_td_append_in_else("*" + token.opt[:content])
      else
        @mes.output_fatal("In :IN_TD unknown tag=(#{token.kind}) in process_one_line_for_in_td")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_td_no_tbody(token, line, lineno, fname)
      case token.kind
      when :ELSE
        table_td_append_in_else(token.opt[:content])
      when :TH
        @layer.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TD
        @layer.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @layer.star)
      when :TABLE_START
        @layer.process_nested_table_start(token, lineno, fname)
      when :TABLE_END
        process_one_line_for_table_end(token)
      when :TBODY_END
        @layer.table.tbody_end
      when :STAR_START
        @layer.star = true
        table_td_append_in_else("*" + token.opt[:content])
      when :STAR_END
        @layer.star = false
        table_td_append_in_else("*" + token.opt[:content])
      else
        @mes.output_fatal("In :IN_TD_NO_TBODY unknown tag=(#{token.kind}) in process_one_line_for_in_td_no_tbody")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line(current_state, token, line, lineno, fname)
      @layer.return_from_nested_env = false

      case current_state
      when :START
        process_one_line_for_start(token, line, lineno, fname)
      when :OUT_OF_TABLE
        process_one_line_for_out_of_table(token, line, lineno, fname)
      when :IN_TABLE
        process_one_line_for_in_table(token, line, lineno, fname)
      when :IN_TABLE_BODY
        process_one_line_for_in_table_body(token, line, lineno, fname)
      when :IN_TH
        process_one_line_for_in_th(token, line, lineno, fname)
      when :IN_TH_NO_TBODY
        process_one_line_for_in_th_no_tbody(token, line, lineno, fname)
      when :IN_TD
        process_one_line_for_in_td(token, line, lineno, fname)
      when :IN_TD_NO_TBODY
        process_one_line_for_in_td_no_tbody(token, line, lineno, fname)
      else
        @mes.output_fatal("In Unknown state(#{current_state}) in process_one_line")
        @mes.output_fatal("@fname=#{@fname} | lineno=#{lineno}")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end

      if @layer.return_from_nested_env
        next_state = @layer.cur_state
      else
        next_state = get_next_state(token, line, lineno, fname)

        @mes.output_debug("#{__LINE__}|next_state=#{next_state}")
      end
      next_state
    end

    def end
      @mes.exc_file_close(@o_fname) { @output.close }
    end
  end
end
