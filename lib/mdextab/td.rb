  class Td
    def initialize(lineno, attr=nil)
      @lineno = lineno
      @attr = attr
      @content = ""
    end

    def add(content, condnese)
      if condnese
        if @content
          if @contnet.match?(/^\s*$/)
            @content=content.to_s
          else
            @content+=content.to_s
          end
        else
          @content=content.to_s
        end
      else
        @content = [@content, content].join("\n") if content
      end
    end

    def to_s
      if @attr != nil
        %Q!<td #{@attr}>#{@content}</td>!
      else
        %Q!<td>#{@content}</td>!
      end
    end
  end
