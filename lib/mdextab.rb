require "mdextab/version"

require 'mdextab/loggerx'
require 'mdextab/token'
require 'mdextab/table'
require 'mdextab/tbody'
require 'mdextab/td'
require 'mdextab/th'
require 'mdextab/token'
require 'mdextab/tr'
require 'mdextab/yamlx'

require 'byebug'

module Mdextab
  class Error < StandardError; end

  class Mdextab
    def initialize(opt, fname, o_fname, yamlfname, auxiliaryYamlFname=nil)
      @fname = fname
      @yamlfname = yamlfname
      @auxiliaryYamlFname = auxiliaryYamlFname

      @envStruct = Struct.new("Env" , :table, :star, :curState)
      @env = nil
      @envs = []

      @exit_nil=1
      @exit_exception=2
      @exit_next_state=3
      @exit_unknown=4
      @exit_table_end=5
      @exit_cannot_find_file=6
      @exit_cannot_write_file=7
      @exit_else=8
      @exit_illeagal_state=100

      @logger = Loggerx.new("log.txt")
      #    @logger.level = Logger::WARN
      #    @logger.level = Logger::INFO
      @logger.level = Logger::DEBUG if opt["debug"]

      # UNKNOWN > FATAL > ERROR > WARN > INFO > DEBUG
      #    @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
      @logger.datetime_format = ''
      #logger.formatter = proc do |severity, datetime, progname, msg|
      #   ">>>>>> #{msg}\n"
      #end
      unless File.exist?(fname)
        mes="Can't find #{fname}"
        if @logger
          @logger.error(mes)
        else
          STDERR.puts(mes)
        end
        exit(@exit_cannot_find_file)
      end

      begin
        @output = File.open(o_fname, 'w')
      rescue => ex
        mes2="Can't write #{o_fname}"
        if @logger
          @logger.error(mes2)
        else
          STDERR.puts(mes2)
        end
        exit(@exit_cannot_write_file)
      end

      @fname = fname
      @state = {
        START: {TABLE_START: :IN_TABLE , ELSE: :OUT_OF_TABLE, STAR_START: :START, STAR_END: :START},
        OUT_OF_TABLE: {TABLE_START: :IN_TABLE , ELSE: :OUT_OF_TABLE, STAR_START: :OUT_OF_TABLE, STAR_END: :OUT_OF_TABLE, TD: :OUT_OF_TABLE },
        IN_TABLE: {TBODY_START: :IN_TABLE_BODY, TABLE_END: :OUT_OF_TABLE, ELSE: :IN_TABLE, TD: :IN_TD_NO_TBODY, TH: :IN_TH_NO_TBODY, TABLE_START: :IN_TABLE, STAR_START: :IN_TABLE, STAR_END: :IN_TABLE},
        IN_TABLE_BODY: { TH: :IN_TH , TD: :IN_TD , ELSE: :IN_TABLE_BODY, TABLE_START: :IN_TABLE, TBODY_END: :IN_TABLE, TABLE_END: :OUT_OF_TABLE, STAR_START: :IN_TABLE_BODY, STAR_END: :IN_TABLE_BODY},
        IN_TH: {ELSE: :IN_TH, TH: :IN_TH, TD: :IN_TD, TABLE_START: :IN_TH, STAR_START: :IN_TH, STAR_END: :IN_TH},
        IN_TH_NO_TBODY: {ELSE: :IN_TH_NO_TBODY, TH: :IN_TH_NO_TBODY, TD: :IN_TD_NO_TBODY, TABLE_START: :IN_TH_NO_TBODY, STAR_START: :IN_TH_NO_TBODY, STAR_END: :IN_TH_NO_TBODY},
        IN_TD: {ELSE: :IN_TD, TH: :IN_TH, TD: :IN_TD, TBODY_END: :IN_TABLE, TABLE_START: :IN_TD, STAR_START: :IN_TD, START_END: :IN_TD},
        IN_TD_NO_TBODY: {ELSE: :IN_TD_NO_TBODY, TH: :IN_TH_NO_TBODY, TD: :IN_TD_NO_TBODY, TABLE_START: :IN_TD_NO_TBODY, TABLE_END: :OUT_OF_TABLE, TBODY_END: :IN_TABLE, STAR_START: :IN_TD_NO_TBODY, STAR_END: :IN_TD_NO_TBODY},
      }

    end

    def getToken(l, lineno)
      case l
      when /^\*S(.+)$/
        content = $1
        ret = Token.new(:STAR_START, {content: content, lineno: lineno})
      when /^\*E(.+)$/
        content = $1
        ret = Token.new(:STAR_END, {content: content, lineno: lineno})
      when /^\s*<table/
        if /^\s*<table>\s*$/.match?(l)
          @logger.debug(%Q!T1 :TABLE_START attr: nil!)
          ret = Token.new(:TABLE_START, {lineno: lineno})
        elsif (m=/^\s*<table\s+(.+)>\s*$/.match(l))
          @logger.debug(%Q!T2 :TABLE_START attr: #{m[1]}!)
          ret = Token.new(:TABLE_START, {attr: m[1], lineno: lineno})
        else
          @logger.debug("E002 l=#{l}")
          ret = nil
        end
      when /^\s*<tbody/
        if /^\s*<tbody>\s*$/.match?(l)
          ret = Token.new(:TBODY_START, {lineno: lineno})
        else
          @logger.debug("E003 l=#{l}")
          ret = nil
        end        

      when /^\s*(\:+)(.*)$/
        nth = $1.size
        cont = $2
        if (m=/^th(.*)/.match(cont))
          cont2 = m[1]
          @logger.debug( %Q!cont2=#{cont2}! )
          if (m2=/^\s(.*)/.match(cont2))
            cont3 = m2[1]
            if (m3=/^([^<]*)>(.*)$/.match(cont3))
              attr = m3[1]
              cont4 = m3[2]
              @logger.debug( %Q!1 :TH , { nth: #{nth} , attr: #{attr} , content: #{cont4}}! )
              ret = Token.new(:TH , { nth: nth , attr: attr , content: cont4, lineno: lineno})
            else
              # error
              #ret = nil
              @logger.debug( %Q!2 :ELSE , { nth: #{nth} , attr: nil , content: #{cont}}! )
              ret = Token.new(:ELSE , { nth: nth , attr: nil , content: cont, lineno: lineno})
            end
          elsif (m=/^>(.*)$/.match(cont2))
            cont3 = m[1]
            @logger.debug( %Q!3 :TH , { nth: #{nth} , attr: nil , content: #{cont3}}! )
            ret = Token.new(:TH , { nth: nth , attr: nil , content: cont3, lineno: lineno})
          else
            @logger.debug( %Q!4 :ELSE , { nth: #{nth} , attr: nil , content: #{cont}}! )
            ret = Token.new(:ELSE , { nth: nth , attr: nil , content: cont, lineno: lineno})
          end
        elsif (m=/^([^<]*)>(.*)$/.match(cont))
          attr = m[1]
          cont2 = m[2]
          @logger.debug( %Q!5 :TD , { nth: #{nth} , attr: #{attr} , content: #{cont2}}! )
          ret = Token.new(:TD , {nth: nth , attr: attr , content: cont2, lineno: lineno})
        else
          @logger.debug( %Q!6 :TD , { nth: #{nth} , attr: #{attr} , content: #{cont}}! )
          ret = Token.new(:TD , { nth: nth , attr: attr , content: cont , lineno: lineno})
        end
      when /^\s*<\/table/
        if /^\s*<\/table>\s*$/.match?(l)
          ret = Token.new(:TABLE_END, {lineno: lineno})
        else
          @logger.debug("E000 l=#{l}")
          ret = nil
        end
      when /^\s*<\/tbody/
        if /^\s*<\/tbody>\s*$/.match?(l)
          ret = Token.new(:TBODY_END, {lineno: lineno})
        else
          @logger.debug("E001 l=#{l}")
          ret = nil
        end
      else
        ret = Token.new(:ELSE, {content: l, lineno: lineno})
      end

      ret
    end

    def parse
      @env = getNewEnv()
      lineno=0
      Yamlx.loadSetting(@yamlfname , @auxiliaryYamlFname, @fname).each{ |l|
        lineno += 1
        token = getToken(l, lineno)
        kind = token.kind

        @logger.debug("kind=#{kind}")
        @logger.debug(%Q!(source)#{lineno}:#{l}!)
        if @env.curState == nil
          @logger.error("(script)#{__LINE__}| @env.curState=nil")
        else
          @logger.debug("(script)#{__LINE__}| @env.curState=#{@env.curState}")
        end
        #        debug_envs(5, token)

        ret = processOneLine(@env.curState, token, l, lineno)
        unless ret
          @logger.error("processOneLine returns nil")
          exit(@exit_next_state)
        end
        @env.curState = ret

        v=@env.curState
        v="nil" unless v
        @logger.debug("NEXT kind=#{kind} @env.curState=#{v}")
        @logger.debug("-----")
      }
      checkEnvs
    end


    def getNextState(token, line)
      kind = token.kind
      @logger.debug("#{__LINE__}|@env.curState=#{@env.curState} #{@env.curState.class}")
      tmp = @state[@env.curState]
      if tmp == nil
        @logger.error(%Q!kind=#{kind}!)
        @logger.error("=== tmp == nil")
        exit(@exit_nil)
      else
        @logger.debug("tmp=#{tmp}")
      end
      @logger.debug("#{__LINE__}|kind=#{kind}")
      
      begin
        nextState = tmp[kind]
        @logger.debug("#{__LINE__}|nextState=#{nextState}")
      rescue
        @logger.fatal(@env.curState)
        @logger.fatal(kind)
        @logger.fatal(nextState)
        @logger.fatal("+++")
        exit(@exit_exception)
      end
      @logger.debug("#{__LINE__}|nextState=#{nextState}")
      nextState
    end

    def debug_envs(n, token)
      @logger.debug( "***#{n}")
      @envs.each_with_index{|x,ind|
        @logger.debug( "@envs[#{ind}]=#{@envs[ind]}")
      }
      @logger.debug( "******#{n}")
      @logger.debug( "getNewEnv 1 token.kind=#{token.kind} @env.curState=#{@env.curState}" )
    end

    def processNestedTableStart(token)
      @logger.debug( "B getNewEnv 1 token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.curState=#{@env.curState}" )
      @env = getNewEnv(:OUT_OF_TABLE)
      @env.table = Table.new(token.opt[:lineno], @logger, token.opt[:attr])
      @logger.debug( "getNewEnv 3 token.kind=#{token.kind} @env.curState=#{@env.curState}" )
    end

    def processTableEnd(token)
#byebug
      prevEnv = peekPrevEnv()
      if prevEnv
        tmp_table = @env.table

        @logger.debug( "B getPrevEnv 1 token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.curState=#{@env.curState}" )
        @logger.debug( "@envs.size=#{@envs.size}")
        @env = getPrevEnv()
        @return_from_nested_env = true
        @logger.debug( "getPrevEnv 1 token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.curState=#{@env.curState}" )

        @logger.debug( "0 - processTableEnd @env.curState=#{@env.curState} @return_from_nested_env=#{@return_from_nested_env}")
        @logger.debug( tmp_table )
        case @env.curState
        when :IN_TD
          @env.table.tdAppend(tmp_table, @env.star)
        when :IN_TD_NO_TBODY
          @env.table.tdAppend(tmp_table, @env.star)
        when :IN_TH
          @env.table.thAppend(tmp_table, @env.star)
        when :IN_TH_NO_TBODY
          @env.table.thAppend(tmp_table,@env.star)
        when :IN_TABLE
          @env.table.add(tmp_table)
        when :IN_TABLE_BODY
          @env.table.add(tmp_table)
        when :START
          # do nothing?
        else
          v = @env.curState
          v = "nil" unless v
          @logger.error("E100 @env.curState=#{v}")
          @logger.error("@env.table=#{@env.table}")
          exit(@exit_table_end)
        end
      else
        @logger.debug( "1 - processTableEnd @env.curState=#{@env.curState} @return_from_nested_env~#{@return_from_nested_env}")
        @output.puts(@env.table.end)
      end
    end

    def outputInElse(str)
      if @env.star
        if str.match?(/^\s*$/)
          @logger.debug("InElse do nothing")
        else
          @output.puts(str)
        end
      else
        @output.puts(str)
      end        
    end

    def tableThAppendInElse(str)
      if @env.star
        if str.match?(/^\s*$/)
          @logger.debug("ThAppend InElse")
        else
          @env.table.thAppend(str,@env.star)
        end
      else
        @env.table.thAppend(str,@env.star)
      end        
    end

    def tableTdAppendInElse(str)
      if @env.star
        if str.match?(/^\s*$/)
          @logger.debug("TdAppend InElse")
        else
          @env.table.tdAppend(str,@env.star)
        end
      else
        @env.table.tdAppend(str,@env.star)
      end        
    end

    def processOneLine(curState, token, line, lineno)
      @return_from_nested_env = false
      case @env.curState
      when :START
        case token.kind
        when :TABLE_START
          @env.table = Table.new(lineno, @logger,token.opt[:attr])
        when :ELSE
          # threw
          outputInElse(token.opt[:content])
        when :STAR_START
          @env.star = true
          outputInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          outputInElse('*'+token.opt[:content])
          outputInElse(token.opt[:content])
        else
          @logger.error( ":START [unknown]")
          exit(@exit_unknown)
        end
      when :OUT_OF_TABLE
        case token.kind
        when :TABLE_START
          @env.table = Table.new(lineno, @logger,token.opt[:attr])
        when :ELSE
          outputInElse(token.opt[:content])
        when :STAR_START
          @env.star = true
          outputInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          outputInElse('*'+token.opt[:content])
          outputInElse(token.opt[:content])
        when :TD
          # ignore this case
        else
          @logger.error( ":OUT_OF_TABLE [unknown]")
          exit(@exit_unknown)
        end
      when :IN_TABLE
        case token.kind
        when :TBODY_START
          @env.table.add_tbody(lineno)
        when :TABLE_END
          processTableEnd(token)
        when :ELSE
          outputInElse(token.opt[:content])
        when :TD
          @logger.debug(token)
          @env.table.add_tbody(lineno)
          @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TH
          @env.table.add_tbody(lineno)
          @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TABLE_START
          @env.table = Table.new(lineno, @logger,token.opt[:attr])
          outputInElse(token.opt[:content])
        when :STAR_START
          @env.star = true
          outputInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false
          outputInElse('*'+token.opt[:content])
        else
          @logger.error( ":IN_TABLE [unknown]")
          exit(@exit_unknown)
        end
      when :IN_TABLE_BODY
        case token.kind
        when :TH
          @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TD
          @logger.debug(token)
          @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :ELSE
          outputInElse(token.opt[:content])
        when :TABLE_START
          processNestedTableStart(token)
        when :TBODY_END
          #  processTableEnd(token)
        when :TABLE_END
          processTableEnd(token)
        when :STAR_START
          @env.star = true
          outputInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          outputInElse('*'+token.opt[:content])
        else
          @logger.error( ":IN_TABLE_BODY [unknown]")
          exit(@exit_unknown)
          #
        end
      when :IN_TH
        case token.kind
        when :ELSE
          tableThAppendInElse(token.opt[:content])
        when :TH
          @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TD
          @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TABLE_START
          #        debug_envs(3, token)
          @env = getNewEnv(:OUT_OF_TABLE)
          @env.table = Table.new(lineno, @logger,token.opt[:attr])
          @logger.debug( "getNewEnv 2 token.kind=#{token.kind} @env.curState=#{@env.curState}" )
          #        debug_envs(4, token)
        when :STAR_START
          @env.star = true
          tableThAppendInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          tableThAppendInElse('*'+token.opt[:content])
        else
          @logger.error( ":IN_TH [unknown]")
          exit(@exit_unknown)
          #
        end
      when :IN_TH_NO_TBODY
        case token.kind
        when :ELSE
          tableThAppendInElse(token.opt[:content])
        when :TH
          @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TD
          @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TABLE_START
          #        debug_envs(3, token)
          @env = getNewEnv(:OUT_OF_TABLE)
          @env.table = Table.new(lineno, @logger,token.opt[:attr])
          @logger.debug( "getNewEnv 2 token.kind=#{token.kind} @env.curState=#{@env.curState}" )
          #        debug_envs(4, token)
        when :STAR_START
          @env.star = true
          tableThAppendInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          tableThAppendInElse('*'+token.opt[:content])
        else
          @logger.error( ":IN_TH_NO_TBODY [unknown]")
          exit(@exit_unknown)
          #
        end
      when :IN_TD
        case token.kind
        when :ELSE
          tableTdAppendInElse(token.opt[:content])
        when :TH
          @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TD
          @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TBODY_END
          @env.table.tbody_end()
        when :TABLE_START
          processNestedTableStart(token)
        when :STAR_START
          @env.star = true
          tableTdAppendInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          tableTdAppendInElse('*'+token.opt[:content])
        else
          @logger.error( ":IN_TD [unknown]")
          exit(@exit_unknown)
          #
        end
      when :IN_TD_NO_TBODY
        case token.kind
        when :ELSE
          tableTdAppendInElse(token.opt[:content])
        when :TH
          @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TD
          @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TABLE_START
          processNestedTableStart(token)
        when :TABLE_END
          processTableEnd(token)
        when :TBODY_END
          @env.table.tbody_end()
        when :STAR_START
          @env.star = true
          tableTdAppendInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          tableTdAppendInElse('*'+token.opt[:content])
        else
          @logger.error( ":IN_TD_NO_TBODY [unknown]")
          exit(@exit_unknown)
          #
        end
      else
        @logger.error( "unknown state")
        exit(@exit_unknown)
        #
      end

      unless @return_from_nested_env
        nextState = getNextState(token, line)
        @logger.debug("#{__LINE__}|nextState=#{nextState}")
      else
        nextState = @env.curState
      end
      nextState
    end

    def end
      @output.close
    end

    def getNewEnv(state=:START)
      new_env = @envStruct.new
      @envs << new_env
      new_env.curState = state
      if @env
        new_env.star = @env.star
      else
        new_env.star = false
      end
      new_env
    end

    def getCurState
      ret = @env.curState
    end

    def getPrevEnv()
      @envs.pop
      @envs.last
    end

    def peekPrevEnv()
      if @envs.size > 1
        @envs[@envs.size-2]
      else
        nil
      end
    end

    def checkEnvs
      case @env.curState
      when :OUT_OF_TABLE
        if @envs.size > 1
          @logger.info("illeagal nested env after parsing|:OUT_OF_TABLE")
          @logger.fatal("@envs.size=#{@envs.size} :TABLE_START #{@env.table.lineno}" )
          @envs.map{ |x| 
            @logger.fatal("== @envs.curState=#{x.curState} :TABLE_START #{x.table.lineno}") 
          }
          @logger.fatal("== @env.table")
          @logger.info(@env.table)
          raise
        end
      when :START
        if @envs.size > 1
          @logger.fatal("illeagal nested env after parsing|:START")
          @logger.fatal("@envs.size=#{@envs.size}")
          @envs.map{ |x| 
            @logger.fatal("== @envs.curState=#{x.curState} :TABLE_START #{x.table.lineno}") 
          }
          @logger.fatal("== @env.table")
          @logger.fatal(@env.table)
          raise
        end
      else
        @logger.fatal("illeagal state after parsing(#{@env.curState}|#{@env.curState.class})")
        @logger.fatal("@envs.size=#{@envs.size}")
        @logger.fatal("== @env.curState=#{@env.curState}")
        @envs.map{ |x| 
          @logger.fatal("== @envs.curState=#{x.curState} #{@fname}:#{x.table.lineno}") 
        }
#        @logger.fatal("== @env.table")
#        @logger.fatal(@env.table)
#        raise
        @logger.fatal("")
        exit(@exit_illeagal_state)
      end
    end
  end
end
