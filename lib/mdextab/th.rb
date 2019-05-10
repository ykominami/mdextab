module Mdextab
  class Th
    def initialize(lineno, attr=nil)
      @lineno = lineno
      @attr = attr
      @content = ""
    end

    def add(content, condense)
      if condense
        if @content
          if @content.match?(/^\s*$/)
            @content = content.to_s
          else
            @content += content.to_s
          end
        else
          @content = content.to_s
        end
      else
        @content = [@content, content].join("\n") if content
      end
    end

    def to_s
      if !@attr.nil?
        %Q(<th #{@attr}>#{@content}</th>)
      else
        %Q(<th>#{@content}</th>)
      end
    end
  end
end
