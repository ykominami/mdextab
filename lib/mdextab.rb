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
    require "messagex/loggerx"
    require "filex"

    require "byebug"

    def initialize(opt, fname, o_fname, mes=nil)
      @fname = fname
      @o_fname = o_fname

      @env_struct = Struct.new(:table, :star, :cur_state)
      @env = nil
      @envs = []

      @mes = mes
      @mes ||= Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, opt["debug"])

      @mes.addExitCode("EXIT_CODE_NEXT_STATE")
      @mes.addExitCode("EXIT_CODE_NIL")
      @mes.addExitCode("EXIT_CODE_EXCEPTION")
      @mes.addExitCode("EXIT_CODE_TABLE_END")
      @mes.addExitCode("EXIT_CODE_UNKNOWN")
      @mes.addExitCode("EXIT_CODE_ILLEAGAL_STATE")

      Filex::Filex.setup(@mes)

      unless File.exist?(fname)
        @mes.outputFatal("Can't find #{fname}")
        exit(@mes.ec("EXIT_CODE_CANNOT_FIND_FILE"))
      end

      dir = File.dirname(o_fname)
      if dir != "."
        @mes.excMakeDirectory(dir) { FileUtils.mkdir_p(dir) }
      end
      @mes.excFileWrite(o_fname) { @output = File.open(o_fname, "w") }

      set_state
    end

    def set_state
      @state = {
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

    def get_token_start_table(line, lineno)
      if /^\s*<table>\s*$/.match?(line)
        ret = Token.new(:TABLE_START, { lineno: lineno })
      elsif (m = /^\s*<table\s+(.+)>\s*$/.match(line))
        ret = Token.new(:TABLE_START, { attr: m[1], lineno: lineno })
      else
        ret = nil
      end
      ret
    end

    def get_token_start_tbody(line, lineno)
      if /^\s*<tbody>\s*$/.match?(line)
        ret = Token.new(:TBODY_START, { lineno: lineno })
      else
        ret = nil
      end
      ret
    end

    def get_token_start_colon(line, lineno, nth, cont)
      if (m = /^th(.*)/.match(cont))
        cont2 = m[1]
        if (m2 = /^\s(.*)/.match(cont2))
          cont3 = m2[1]
          if (m3 = /^([^<]*)>(.*)$/.match(cont3))
            attr = m3[1]
            cont4 = m3[2]
            ret = Token.new(:TH, { nth: nth, attr: attr, content: cont4, lineno: lineno })
          else
            # error
            # ret = nil
            ret = Token.new(:ELSE, { nth: nth, attr: nil, content: cont, lineno: lineno })
          end
        elsif (m = /^>(.*)$/.match(cont2))
          cont3 = m[1]
          ret = Token.new(:TH, { nth: nth, attr: nil, content: cont3, lineno: lineno })
        else
          ret = Token.new(:ELSE, { nth: nth, attr: nil, content: cont, lineno: lineno })
        end
      elsif (m = /^([^<]*)>(.*)$/.match(cont))
        attr = m[1]
        cont2 = m[2]
        ret = Token.new(:TD, { nth: nth, attr: attr, content: cont2, lineno: lineno })
      else
        ret = Token.new(:TD, { nth: nth, attr: attr, content: cont, lineno: lineno })
      end
      ret
    end

    def get_token_end_table(line, lineno)
      if %r{^\s*</table>\s*$}.match?(line)
        ret = Token.new(:TABLE_END, { lineno: lineno })
      else
        ret = nil
      end
      ret
    end

    def get_token(line, lineno)
      case line
      when /^\*S(.+)$/
        content = Regexp.last_match(1)
        ret = Token.new(:STAR_START, { content: content, lineno: lineno })
      when /^\*E(.+)$/
        content = Regexp.last_match(1)
        ret = Token.new(:STAR_END, { content: content, lineno: lineno })
      when /^\s*<table/
        ret = get_token_start_table(line, lineno)
      when /^\s*<tbody/
        ret = get_token_start_tbody(line, lineno)
      when /^\s*(\:+)(.*)$/
        nth = Regexp.last_match(1).size
        cont = Regexp.last_match(2)
        ret = get_token_start_colon(line, lineno, nth, cont)
      when %r{^\s*</table}
        ret = get_token_end_table(line, lineno)
      when %r{^\s*</tbody}
        if %r{^\s*</tbody>\s*$}.match?(line)
          ret = Token.new(:TBODY_END, { lineno: lineno })
        else
          @mes.outputDebug("E001 line=#{line}")
          ret = nil
        end
      else
        ret = Token.new(:ELSE, { content: line, lineno: lineno })
      end

      ret
    end

    def parse(hash)
      @env = get_new_env
      lineno = 0
      Filex::Filex.check_and_expand_file_lines(@fname, hash, @mes).each do |line|
        lineno += 1
        token = get_token(line, lineno)
        kind = token.kind

        @mes.outputDebug("kind=#{kind}")
        @mes.outputDebug(%Q!(source)#{lineno}:#{line}!)
        if @env.cur_state.nil?
          @mes.outputError("(script)#{__LINE__}| @env.cur_state=nil")
        else
          @mes.outputDebug("(script)#{__LINE__}| @env.cur_state=#{@env.cur_state}")
        end
        #        debug_envs(5, token)

        ret = process_one_line(@env.cur_state, token, line, lineno)
        unless ret
          @mes.outputFatal("process_one_line returns nil")
          exit(@mes.ec("EXIT_CODE_NEXT_STATE"))
        end
        @env.cur_state = ret

        v = @env.cur_state
        v ||= "nil"
        @mes.outputDebug("NEXT kind=#{kind} @env.cur_state=#{v}")
        @mes.outputDebug("-----")
      end
      check_envs
    end

    def parse2(yamlfname)
      hs = Filex::Filex.check_and_load_yamlfile(yamlfname, @mes)
      parse(hs)
    end

    def get_next_state(token, line)
      kind = token.kind
      @mes.outputDebug("#{__LINE__}|@env.cur_state=#{@env.cur_state} #{@env.cur_state.class}")
      tmp = @state[@env.cur_state]
      if tmp.nil?
        @mes.outputError(%Q(kind=#{kind}))
        @mes.outputError("=== tmp == nil")
        @mes.outputFatal("Next State is nil")
        exit(@mes.ec("EXIT_CODE_NIL"))
      else
        @mes.outputDebug("tmp=#{tmp}")
      end
      @mes.outputDebug("#{__LINE__}|kind=#{kind}")

      begin
        next_state = tmp[kind]
        @mes.outputDebug("#{__LINE__}|next_state=#{next_state}")
      rescue StandardError
        @mes.outputFatal(@env.cur_state)
        @mes.outputFatal(kind)
        @mes.outputFatal(next_state)
        @mes.outputFatal("+++")
        exit(@mes.ec("EXIT_CODE_EXCEPTION"))
      end
      @mes.outputDebug("#{__LINE__}|next_state=#{next_state}")
      next_state
    end

    def debug_envs(nth, token)
      @mes.outputDebug("***#{nth}")
      @envs.each_with_index {|_x, ind| @mes.outputDebug("@envs[#{ind}]=#{@envs[ind]}") }
      @mes.outputDebug("******#{nth}")
      @mes.outputDebug("get_new_env 1 token.kind=#{token.kind} @env.cur_state=#{@env.cur_state}")
    end

    def process_nested_table_start(token, lineno)
      if @env.table.tbody.nil?
        @env.table.add_tbody(lineno)
      end
      @mes.outputDebug("B get_new_env 1 token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.cur_state=#{@env.cur_state}")
      @env = get_new_env(:OUT_OF_TABLE)
      @env.table = Table.new(token.opt[:lineno], @mes, token.opt[:attr])
      @mes.outputDebug("get_new_env 3 token.kind=#{token.kind} @env.cur_state=#{@env.cur_state}")
    end

    def process_table_end_for_prev_env(token, prev_env)
      tmp_table = @env.table
      @env = prev_env
      @return_from_nested_env = true

      case @env.cur_state
      when :IN_TD
        @env.table.td_append(tmp_table, @env.star)
      when :IN_TD_NO_TBODY
        @env.table.td_append(tmp_table, @env.star)
      when :IN_TH
        @env.table.th_append(tmp_table, @env.star)
      when :IN_TH_NO_TBODY
        @env.table.th_append(tmp_table, @env.star)
      when :IN_TABLE
        if @env.table.nil?
          @mes.outputDebug("In process_nested_table_env_for_prev_env: @env.table=nil token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.cur_state=#{@env.cur_state}")
          raise
        end
        @env.table.add(tmp_table)
      when :IN_TABLE_BODY
        @env.table.add(tmp_table)
      when :START
        @mes.outputDebug("In process_nested_table_env_for_prev_env: @env.table=nil token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.cur_state=#{@env.cur_state}")
        raise
      else
        v = @env.cur_state || "nil"
        @mes.outputFatal("E100 @env.cur_state=#{v}")
        @mes.outputFatal("@env.table=#{@env.table}")
        @mes.outputFatal("IllegalState(#{@env.cur_state} in process_table_end(#{token})")
        exit(@mes.ec("EXIT_CODE_TABLE_END"))
      end
    end

    def process_table_end(token)
      prev_env = peek_prev_env
      if prev_env
        process_table_end_for_prev_env(token, prev_env)
      else
        @mes.outputDebug("1 - process_table_end @env.cur_state=#{@env.cur_state} @return_from_nested_env~#{@return_from_nested_env}")
        @mes.excFileWrite(@o_fname) { @output.puts(@env.table.end) }
      end
    end

    def output_in_else(str)
      if @env.star
        if str.match?(/^\s*$/)
          @mes.outputDebug("InElse do nothing")
        else
          @mes.excFileWrite(@o_fname) { @output.puts(str) }
        end
      else
        @mes.excFileWrite(@o_fname) { @output.puts(str) }
      end
    end

    def table_th_append_in_else(str)
      if @env.star
        if str.match?(/^\s*$/)
          @mes.outputDebug("ThAppend InElse")
        else
          @env.table.th_append(str, @env.star)
        end
      else
        @env.table.th_append(str, @env.star)
      end
    end

    def table_td_append_in_else(str)
      if @env.star
        if str.match?(/^\s*$/)
          @mes.outputDebug("TdAppend InElse")
        else
          @env.table.td_append(str, @env.star)
        end
      else
        @env.table.td_append(str, @env.star)
      end
    end

    def process_one_line_for_start(token, line, lineno)
      case token.kind
      when :TABLE_START
        @env.table = Table.new(lineno, @mes, token.opt[:attr])
      when :ELSE
        # threw
        output_in_else(token.opt[:content])
      when :STAR_START
        @env.star = true
        output_in_else("*" + token.opt[:content])
      when :STAR_END
        @env.star = false
        output_in_else("*" + token.opt[:content])
        output_in_else(token.opt[:content])
      else
        @mes.outputFatal("In :START unknown tag=(#{token.kind}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_out_of_table(token, line, lineno)
      case token.kind
      when :TABLE_START
        @env.table = Table.new(lineno, @mes, token.opt[:attr])
      when :ELSE
        output_in_else(token.opt[:content])
      when :STAR_START
        @env.star = true
        output_in_else("*" + token.opt[:content])
      when :STAR_END
        @env.star = false
        output_in_else("*" + token.opt[:content])
        output_in_else(token.opt[:content])
      when :TD
        # treat as :ELSE
        output_in_else(":" + token.opt[:content])
      else
        @mes.outputFatal("In :OUT_OF_TABLE unknown tag=(#{token.kind}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_table(token, line, lineno)
      case token.kind
      when :TBODY_START
        @env.table.add_tbody(lineno)
      when :TABLE_END
        process_table_end(token)
      when :ELSE
        output_in_else(token.opt[:content])
      when :TD
        @mes.outputDebug(token)
        @env.table.add_tbody(lineno)
        @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TH
        @env.table.add_tbody(lineno)
        @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TABLE_START
        process_nested_table_start(token, lineno)
      when :STAR_START
        @env.star = true
        output_in_else("*" + token.opt[:content])
      when :STAR_END
        @env.star = false
        output_in_else("*" + token.opt[:content])
      else
        @mes.outputFatal("In :IN_TABLE unknown tag=(#{token.kind}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_table_body(token, line, lineno)
      case token.kind
      when :TH
        @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TD
        @mes.outputDebug(token)
        @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :ELSE
        output_in_else(token.opt[:content])
      when :TABLE_START
        process_nested_table_start(token, lineno)
      when :TBODY_END
        true #  don't call process_table_end(token)
      when :TABLE_END
        process_table_end(token)
      when :STAR_START
        @env.star = true
        output_in_else("*" + token.opt[:content])
      when :STAR_END
        @env.star = false
        output_in_else("*" + token.opt[:content])
      else
        @mes.outputFatal("In :IN_TABLE_BODY unknown tag=(#{token.kind}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_th(token, line, lineno)
      case token.kind
      when :ELSE
        table_th_append_in_else(token.opt[:content])
      when :TH
        @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TD
        @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TABLE_START
        process_nested_table_start(token, lineno)
      when :STAR_START
        @env.star = true
        table_th_append_in_else("*" + token.opt[:content])
      when :STAR_END
        @env.star = false
        table_th_append_in_else("*" + token.opt[:content])
      else
        @mes.outputFatal("In :IN_TH unknown tag=(#{token.kind}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_th_no_tbody(token, line, lineno)
      case token.kind
      when :ELSE
        table_th_append_in_else(token.opt[:content])
      when :TH
        @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TD
        @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TABLE_START
        process_nested_table_start(token, lineno)
      when :STAR_START
        @env.star = true
        table_th_append_in_else("*" + token.opt[:content])
      when :STAR_END
        @env.star = false
        table_th_append_in_else("*" + token.opt[:content])
      else
        @mes.outputFatal("In :IN_TH_NO_TBODY unknown tag=(#{token.kind}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_td(token, line, lineno)
      case token.kind
      when :ELSE
        table_td_append_in_else(token.opt[:content])
      when :TH
        @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TD
        @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TBODY_END
        @env.table.tbody_end
      when :TABLE_START
        process_nested_table_start(token, lineno)
      when :STAR_START
        @env.star = true
        table_td_append_in_else("*" + token.opt[:content])
      when :STAR_END
        @env.star = false
        table_td_append_in_else("*" + token.opt[:content])
      else
        @mes.outputFatal("In :IN_TD unknown tag=(#{token.kind}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line_for_in_td_no_tbody(token, line, lineno)
      case token.kind
      when :ELSE
        table_td_append_in_else(token.opt[:content])
      when :TH
        @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TD
        @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr], @env.star)
      when :TABLE_START
        process_nested_table_start(token, lineno)
      when :TABLE_END
        process_table_end(token)
      when :TBODY_END
        @env.table.tbody_end
      when :STAR_START
        @env.star = true
        table_td_append_in_else("*" + token.opt[:content])
      when :STAR_END
        @env.star = false
        table_td_append_in_else("*" + token.opt[:content])
      else
        @mes.outputFatal("In :IN_TD_NO_TBODY unknown tag=(#{token.kind}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end
    end

    def process_one_line(cur_state, token, line, lineno)
      @return_from_nested_env = false

      case cur_state
      when :START
        process_one_line_for_start(token, line, lineno)
      when :OUT_OF_TABLE
        process_one_line_for_out_of_table(token, line, lineno)
      when :IN_TABLE
        process_one_line_for_in_table(token, line, lineno)
      when :IN_TABLE_BODY
        process_one_line_in_table_body(token, line, lineno)
      when :IN_TH
        process_one_line_for_in_th(token, line, lineno)
      when :IN_TH_NO_TBODY
        process_one_line_for_in_th_no_tbody(token, line, lineno)
      when :IN_TD
        process_one_line_for_in_td(token, line, lineno)
      when :IN_TD_NO_TBODY
        process_one_line_for_in_td_no_tbody(token, line, lineno)
      else
        @mes.outputFatal("In Unknown state(#{cur_state}) in process_one_line")
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
      end

      if @return_from_nested_env
        next_state = cur_state
      else
        next_state = get_next_state(token, line)

        @mes.outputDebug("#{__LINE__}|next_state=#{next_state}")
      end
      next_state
    end

    def end
      @mes.excFileClose(@o_fname) { @output.close }
    end

    def get_new_env(state=:START)
      new_env = @env_struct.new
      @envs << new_env
      new_env.cur_state = state
      if @env
        new_env.star = @env.star
      else
        new_env.star = false
      end
      new_env
    end

    # def get_cur_state
    #   ret = @env.cur_state
    # end

    def prev_env
      @envs.pop
      @envs.last
    end

    def peek_prev_env
      return nil unless @envs.size > 1

      @envs[@envs.size - 2]
    end

    def check_envs
      case @env.cur_state
      when :OUT_OF_TABLE
        if @envs.size > 1
          @mes.outputFatal("illeagal nested env after parsing|:OUT_OF_TABLE")
          @mes.outputFatal("@envs.size=#{@envs.size} :TABLE_START #{@env.table.lineno}")
          @envs.map {|x| @mes.outputDebug("== @envs.cur_state=#{x.cur_state} :TABLE_START #{x.table.lineno}") }
          @mes.outputDebug("== @env.table")
          @mes.outputInfo(@env.table)
          exit(@mes.ec("EXIT_CODE_EXCEPTION"))
        end
      when :START
        if @envs.size > 1
          @mes.outputFatal("illeagal nested env after parsing|:START")
          @mes.outputFatal("@envs.size=#{@envs.size}")
          @envs.map {|x| @mes.outputError("== @envs.cur_state=#{x.cur_state} :TABLE_START #{x.table.lineno}") }
          @mes.outputError("== @env.table")
          @mes.outputError(@env.table)
          exit(@mes.ec("EXIT_CODE_EXCEPTION"))
        end
      else
        @mes.outputFatal("illeagal state after parsing(#{@env.cur_state}|#{@env.cur_state.class})")
        @mes.outputFatal("@envs.size=#{@envs.size}")
        @mes.outputError("== @env.cur_state=#{@env.cur_state}")
        @envs.map {|x| @mes.outputError("== @envs.cur_state=#{x.cur_state} #{@fname}:#{x.table.lineno}") }
        @mes.outputError("")
        exit(@mes.ec("EXIT_CODE_ILLEAGAL_STATE"))
      end
    end
  end
end
