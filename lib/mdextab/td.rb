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
      %Q(<td>#{@content}</td>)
    else
      %Q(<td #{@attr}>#{@content}</td>)
    end
  end
end
