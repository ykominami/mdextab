module Mdextab
  class Error < StandardError; end

  class Mdextab
require "mdextab/version"
require 'mdextab/token'
require 'mdextab/table'
require 'mdextab/tbody'
require 'mdextab/td'
require 'mdextab/th'
require 'mdextab/token'
require 'mdextab/tr'
require 'mdextab/makemdtab'
require 'messagex/loggerx'
require 'filex'

require 'byebug'

    def initialize(opt, fname, o_fname, mes=nil)
      @fname=fname
      @o_fname=o_fname

      @envStruct = Struct.new(:table, :star, :curState)
      @env = nil
      @envs = []

      @mes=mes
      unless @mes
        @mes=Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, opt["debug"])
      end

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

      dir=File.dirname(o_fname)
      if dir != "."
        @mes.excMakeDirectory(dir){
         FileUtils.mkdir_p(dir)
        }
      end
      @mes.excFileWrite(o_fname){
        @output = File.open(o_fname, 'w')
      }

      @state = {
        START: {TABLE_START: :IN_TABLE , ELSE: :OUT_OF_TABLE, STAR_START: :START, STAR_END: :START},
        OUT_OF_TABLE: {TABLE_START: :IN_TABLE , ELSE: :OUT_OF_TABLE, STAR_START: :OUT_OF_TABLE, STAR_END: :OUT_OF_TABLE, TD: :OUT_OF_TABLE },
        IN_TABLE: {TBODY_START: :IN_TABLE_BODY, TABLE_END: :OUT_OF_TABLE, ELSE: :IN_TABLE, TD: :IN_TD_NO_TBODY, TH: :IN_TH_NO_TBODY, TABLE_START: :IN_TABLE, STAR_START: :IN_TABLE, STAR_END: :IN_TABLE},
        IN_TABLE_BODY: { TH: :IN_TH , TD: :IN_TD , ELSE: :IN_TABLE_BODY, TABLE_START: :IN_TABLE_BODY, TBODY_END: :IN_TABLE, TABLE_END: :OUT_OF_TABLE, STAR_START: :IN_TABLE_BODY, STAR_END: :IN_TABLE_BODY},
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
          @mes.outputDebug(%Q!T1 :TABLE_START attr: nil!)
          ret = Token.new(:TABLE_START, {lineno: lineno})
        elsif (m=/^\s*<table\s+(.+)>\s*$/.match(l))
          @mes.outputDebug(%Q!T2 :TABLE_START attr: #{m[1]}!)
          ret = Token.new(:TABLE_START, {attr: m[1], lineno: lineno})
        else
          @mes.outputDebug("E002 l=#{l}")
          ret = nil
        end
      when /^\s*<tbody/
        if /^\s*<tbody>\s*$/.match?(l)
          ret = Token.new(:TBODY_START, {lineno: lineno})
        else
          @mes.outputDebug("E003 l=#{l}")
          ret = nil
        end        

      when /^\s*(\:+)(.*)$/
        nth = $1.size
        cont = $2
        if (m=/^th(.*)/.match(cont))
          cont2 = m[1]
          @mes.outputDebug( %Q!cont2=#{cont2}! )
          if (m2=/^\s(.*)/.match(cont2))
            cont3 = m2[1]
            if (m3=/^([^<]*)>(.*)$/.match(cont3))
              attr = m3[1]
              cont4 = m3[2]
              @mes.outputDebug( %Q!1 :TH , { nth: #{nth} , attr: #{attr} , content: #{cont4}}! )
              ret = Token.new(:TH , { nth: nth , attr: attr , content: cont4, lineno: lineno})
            else
              # error
              #ret = nil
              @mes.outputDebug( %Q!2 :ELSE , { nth: #{nth} , attr: nil , content: #{cont}}! )
              ret = Token.new(:ELSE , { nth: nth , attr: nil , content: cont, lineno: lineno})
            end
          elsif (m=/^>(.*)$/.match(cont2))
            cont3 = m[1]
            @mes.outputDebug( %Q!3 :TH , { nth: #{nth} , attr: nil , content: #{cont3}}! )
            ret = Token.new(:TH , { nth: nth , attr: nil , content: cont3, lineno: lineno})
          else
            @mes.outputDebug( %Q!4 :ELSE , { nth: #{nth} , attr: nil , content: #{cont}}! )
            ret = Token.new(:ELSE , { nth: nth , attr: nil , content: cont, lineno: lineno})
          end
        elsif (m=/^([^<]*)>(.*)$/.match(cont))
          attr = m[1]
          cont2 = m[2]
          @mes.outputDebug( %Q!5 :TD , { nth: #{nth} , attr: #{attr} , content: #{cont2}}! )
          ret = Token.new(:TD , {nth: nth , attr: attr , content: cont2, lineno: lineno})
        else
          @mes.outputDebug( %Q!6 :TD , { nth: #{nth} , attr: #{attr} , content: #{cont}}! )
          ret = Token.new(:TD , { nth: nth , attr: attr , content: cont , lineno: lineno})
        end
      when /^\s*<\/table/
        if /^\s*<\/table>\s*$/.match?(l)
          ret = Token.new(:TABLE_END, {lineno: lineno})
        else
          @mes.outputDebug("E000 l=#{l}")
          ret = nil
        end
      when /^\s*<\/tbody/
        if /^\s*<\/tbody>\s*$/.match?(l)
          ret = Token.new(:TBODY_END, {lineno: lineno})
        else
          @mes.outputDebug("E001 l=#{l}")
          ret = nil
        end
      else
        ret = Token.new(:ELSE, {content: l, lineno: lineno})
      end

      ret
    end

    def parse(hs)
      @env = getNewEnv()
      lineno=0
      Filex::Filex::checkAndExpandFileLines(@fname, hs, @mes).each{ |l|
        lineno += 1
        token = getToken(l, lineno)
        kind = token.kind

        @mes.outputDebug("kind=#{kind}")
        @mes.outputDebug(%Q!(source)#{lineno}:#{l}!)
        if @env.curState == nil
          @mes.outputError("(script)#{__LINE__}| @env.curState=nil")
        else
          @mes.outputDebug("(script)#{__LINE__}| @env.curState=#{@env.curState}")
        end
        #        debug_envs(5, token)

        ret = processOneLine(@env.curState, token, l, lineno)
        unless ret
          @mes.outputFatal("processOneLine returns nil")
          exit(@mes.ec("EXIT_CODE_NEXT_STATE"))
        end
        @env.curState = ret

        v=@env.curState
        v="nil" unless v
        @mes.outputDebug("NEXT kind=#{kind} @env.curState=#{v}")
        @mes.outputDebug("-----")
      }
      checkEnvs
    end

    def parse2(yamlfname)
      hs=Filex::Filex.checkAndLoadYamlfile(yamlfname, @mes)
      parse(hs)
    end

    def getNextState(token, line)
      kind = token.kind
      @mes.outputDebug("#{__LINE__}|@env.curState=#{@env.curState} #{@env.curState.class}")
      tmp = @state[@env.curState]
      if tmp == nil
        @mes.outputError(%Q!kind=#{kind}!)
        @mes.outputError("=== tmp == nil")
        @mes.outputFatal("Next State is nil")
        exit(@mes.ec("EXIT_CODE_NIL"))
      else
        @mes.outputDebug("tmp=#{tmp}")
      end
      @mes.outputDebug("#{__LINE__}|kind=#{kind}")
      
      begin
        nextState = tmp[kind]
        @mes.outputDebug("#{__LINE__}|nextState=#{nextState}")
      rescue
        @mes.outputFatal(@env.curState)
        @mes.outputFatal(kind)
        @mes.outputFatal(nextState)
        @mes.outputFatal("+++")
        exit(@mes.ec("EXIT_CODE_EXCEPTION"))
      end
      @mes.outputDebug("#{__LINE__}|nextState=#{nextState}")
      nextState
    end

    def debug_envs(n, token)
      @mes.outputDebug( "***#{n}")
      @envs.each_with_index{|x,ind|
        @mes.outputDebug( "@envs[#{ind}]=#{@envs[ind]}")
      }
      @mes.outputDebug( "******#{n}")
      @mes.outputDebug( "getNewEnv 1 token.kind=#{token.kind} @env.curState=#{@env.curState}" )
    end

    def processNestedTableStart(token, lineno)
      if @env.table.tbody == nil
        @env.table.add_tbody(lineno)
      end
      @mes.outputDebug( "B getNewEnv 1 token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.curState=#{@env.curState}" )
      @env = getNewEnv(:OUT_OF_TABLE)
      @env.table = Table.new(token.opt[:lineno], @mes, token.opt[:attr])
      @mes.outputDebug( "getNewEnv 3 token.kind=#{token.kind} @env.curState=#{@env.curState}" )
    end

    def processTableEnd(token)
      prevEnv = peekPrevEnv()
      if prevEnv
        tmp_table = @env.table

        @mes.outputDebug( "B getPrevEnv 1 token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.curState=#{@env.curState}" )
        @mes.outputDebug( "@envs.size=#{@envs.size}")
        @env = getPrevEnv()
        @return_from_nested_env = true
        @mes.outputDebug( "getPrevEnv 1 token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.curState=#{@env.curState}" )

        @mes.outputDebug( "0 - processTableEnd @env.curState=#{@env.curState} @return_from_nested_env=#{@return_from_nested_env}")
        @mes.outputDebug( tmp_table )
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
          if @env.table == nil
            @mes.outputDebug( "In processNestedTableEnv: @env.table=nil token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} @env.curState=#{@env.curState}" )
            raise
          end
          @env.table.add(tmp_table)
        when :IN_TABLE_BODY
          @env.table.add(tmp_table)
        when :START
          # do nothing?
        else
          v = @env.curState
          v = "nil" unless v
          @mes.outputFatal("E100 @env.curState=#{v}")
          @mes.outputFatal("@env.table=#{@env.table}")
          @mes.outputFatal("IllegalState(#{@env.curState} in processTableEnd(#{token})")
          exit(@mes.ec("EXIT_CODE_TABLE_END"))
        end
      else
        @mes.outputDebug( "1 - processTableEnd @env.curState=#{@env.curState} @return_from_nested_env~#{@return_from_nested_env}")
        @mes.excFileWrite(@o_fname){
          @output.puts(@env.table.end)
        }
      end
    end

    def outputInElse(str)
      if @env.star
        if str.match?(/^\s*$/)
          @mes.outputDebug("InElse do nothing")
        else
          @mes.excFileWrite(@o_fname){
            @output.puts(str)
          }
        end
      else
        @mes.excFileWrite(@o_fname){
          @output.puts(str)
        }
      end        
    end

    def tableThAppendInElse(str)
      if @env.star
        if str.match?(/^\s*$/)
          @mes.outputDebug("ThAppend InElse")
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
          @mes.outputDebug("TdAppend InElse")
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
          @env.table = Table.new(lineno, @mes, token.opt[:attr])
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
          @mes.outputFatal("In :START unknown tag=(#{token.kind}) in processOneLine")
          exit(@mes.ec("EXIT_CODE_UNKNOWN"))
        end
      when :OUT_OF_TABLE
        case token.kind
        when :TABLE_START
          @env.table = Table.new(lineno, @mes,token.opt[:attr])
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
          # treat as :ELSE
          outputInElse(":" + token.opt[:content])
        else
          @mes.outputFatal("In :OUT_OF_TABLE unknown tag=(#{token.kind}) in processOneLine")          
          exit(@mes.ec("EXIT_CODE_UNKNOWN"))
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
          @mes.outputDebug(token)
          @env.table.add_tbody(lineno)
          @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TH
          @env.table.add_tbody(lineno)
          @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TABLE_START
          processNestedTableStart(token, lineno)
        when :STAR_START
          @env.star = true
          outputInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false
          outputInElse('*'+token.opt[:content])
        else
          @mes.outputFatal("In :IN_TABLE unknown tag=(#{token.kind}) in processOneLine")          
          exit(@mes.ec("EXIT_CODE_UNKNOWN"))
        end
      when :IN_TABLE_BODY
        case token.kind
        when :TH
          @env.table.add_th(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :TD
          @mes.outputDebug(token)
          @env.table.add_td(lineno, token.opt[:content], token.opt[:nth], token.opt[:attr],@env.star)
        when :ELSE
          outputInElse(token.opt[:content])
        when :TABLE_START
          processNestedTableStart(token, lineno)
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
          @mes.outputFatal("In :IN_TABLE_BODY unknown tag=(#{token.kind}) in processOneLine")          
          exit(@mes.ec("EXIT_CODE_UNKNOWN"))
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
          processNestedTableStart(token, lineno)
        when :STAR_START
          @env.star = true
          tableThAppendInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          tableThAppendInElse('*'+token.opt[:content])
        else
          @mes.outputFatal("In :IN_TH unknown tag=(#{token.kind}) in processOneLine")          
          exit(@mes.ec("EXIT_CODE_UNKNOWN"))
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
          processNestedTableStart(token, lineno)
        when :STAR_START
          @env.star = true
          tableThAppendInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          tableThAppendInElse('*'+token.opt[:content])
        else
          @mes.outputFatal("In :IN_TH_NO_TBODY unknown tag=(#{token.kind}) in processOneLine")          
          exit(@mes.ec("EXIT_CODE_UNKNOWN"))
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
          processNestedTableStart(token, lineno)
        when :STAR_START
          @env.star = true
          tableTdAppendInElse('*'+token.opt[:content])
        when :STAR_END
          @env.star = false       
          tableTdAppendInElse('*'+token.opt[:content])
        else
          @mes.outputFatal("In :IN_TD unknown tag=(#{token.kind}) in processOneLine")
          exit(@mes.ec("EXIT_CODE_UNKNOWN"))
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
          processNestedTableStart(token, lineno)
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
          @mes.outputFatal("In :IN_TD_NO_TBODY unknown tag=(#{token.kind}) in processOneLine")          
          exit(@mes.ec("EXIT_CODE_UNKNOWN"))
          #
        end
      else
        @mes.outputFatal("In Unknown state(#{@env.curState}) in processOneLine")          
        exit(@mes.ec("EXIT_CODE_UNKNOWN"))
        #
      end

      unless @return_from_nested_env
        nextState = getNextState(token, line)

        @mes.outputDebug("#{__LINE__}|nextState=#{nextState}")
      else
        nextState = @env.curState
      end
      nextState
    end

    def end
      @mes.excFileClose(@o_fname){
        @output.close
      }
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
          @mes.outputFatal("illeagal nested env after parsing|:OUT_OF_TABLE")
          @mes.outputFatal("@envs.size=#{@envs.size} :TABLE_START #{@env.table.lineno}" )
          @envs.map{ |x| 
            @mes.outputDebug("== @envs.curState=#{x.curState} :TABLE_START #{x.table.lineno}") 
          }
          @mes.outputDebug("== @env.table")
          @mes.outputInfo(@env.table)
          exit(@mes.ec("EXIT_CODE_EXCEPTION"))
        end
      when :START
        if @envs.size > 1
          @mes.outputFatal("illeagal nested env after parsing|:START")
          @mes.outputFatal("@envs.size=#{@envs.size}")
          @envs.map{ |x| 
            @mes.outputError("== @envs.curState=#{x.curState} :TABLE_START #{x.table.lineno}") 
          }
          @mes.outputError("== @env.table")
          @mes.outputError(@env.table)
          exit(@mes.ec("EXIT_CODE_EXCEPTION"))
        end
      else
        @mes.outputFatal("illeagal state after parsing(#{@env.curState}|#{@env.curState.class})")
        @mes.outputFatal("@envs.size=#{@envs.size}")
        @mes.outputError("== @env.curState=#{@env.curState}")
        @envs.map{ |x| 
          @mes.outputError("== @envs.curState=#{x.curState} #{@fname}:#{x.table.lineno}") 
        }
        @mes.outputError("")
        exit(@mes.ed("EXIT_CODE_ILLEAGAL_STATE"))
      end
    end
  end
end
