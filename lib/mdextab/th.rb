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
      elsif content
        @content = [@content, content].join("\n")
      end
    end

    def to_s
      if @attr.nil?
        %Q(<th>#{@content}</th>)
      else
        %Q(<th #{@attr}>#{@content}</th>)
      end
    end
  end
end
