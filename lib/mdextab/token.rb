module Mdextab
  class Token
    attr_reader :kind, :opt

    def initialize(mes)
      @mes = mes
      @token_struct = Struct.new(:kind, :opt)
    end

    def create_token(kind, opt={})
      @token_struct.new(kind, opt)
    end

    def get_token_start_table(line, lineno)
      if /^\s*<table>\s*$/.match?(line)
        ret = create_token(:TABLE_START, { lineno: lineno })
      elsif (m = /^\s*<table\s+(.+)>\s*$/.match(line))
        ret = create_token(:TABLE_START, { attr: m[1], lineno: lineno })
      else
        ret = nil
      end
      ret
    end

    def get_token_start_tbody(line, lineno)
      if /^\s*<tbody>\s*$/.match?(line)
        ret = create_token(:TBODY_START, { lineno: lineno })
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
            ret = create_token(:TH, { nth: nth, attr: attr, content: cont4, lineno: lineno })
          else
            # error
            # ret = nil
            ret = create_token(:ELSE, { nth: nth, attr: nil, content: cont, lineno: lineno })
          end
        elsif (m = /^>(.*)$/.match(cont2))
          cont3 = m[1]
          ret = create_token(:TH, { nth: nth, attr: nil, content: cont3, lineno: lineno })
        else
          ret = create_token(:ELSE, { nth: nth, attr: nil, content: cont, lineno: lineno })
        end
      elsif (m = /^([^<]*)>(.*)$/.match(cont))
        attr = m[1]
        cont2 = m[2]
        ret = create_token(:TD, { nth: nth, attr: attr, content: cont2, lineno: lineno })
      else
        ret = create_token(:TD, { nth: nth, attr: attr, content: cont, lineno: lineno })
      end
      ret
    end

    def get_token_end_table(line, lineno)
      if %r{^\s*</table>\s*$}.match?(line)
        ret = create_token(:TABLE_END, { lineno: lineno })
      else
        ret = nil
      end
      ret
    end

    def get_token(line, lineno)
      case line
      when /^\*S(.+)$/
        content = Regexp.last_match(1)
        ret = create_token(:STAR_START, { content: content, lineno: lineno })
      when /^\*E(.+)$/
        content = Regexp.last_match(1)
        ret = create_token(:STAR_END, { content: content, lineno: lineno })
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
          ret = create_token(:TBODY_END, { lineno: lineno })
        else
          @mes.outputDebug("E001 line=#{line}")
          ret = nil
        end
      else
        ret = create_token(:ELSE, { content: line, lineno: lineno })
      end

      ret
    end
  end
end
