module Mdextab
  #
  # TDトークン対応クラス
  class Td
    #
    # 初期化
    #
    # @param lineno [String] TDトークン出現行の行番号
    # @param attr [String] TDトークンの属性
    def initialize(lineno, attr=nil)
      @lineno = lineno
      @attr = attr
      @content = ""
    end

    #
    # TDトークンのコンテンツ追加
    #
    # @param content [String] TDトークンのコンテンツ
    # @param condense [Boolean] 文字列化方法 true:改行を含めない false:改行を含める
    # @return [void]
    def add(content, condense)
      if condense
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

    #
    # tdの文字列化
    #
    # @return [String] HTMLのTDタグとして文字列化したもの
    def to_s
      if @attr.nil?
        %(<td>#{@content}</td>)
      else
        %(<td #{@attr}>#{@content}</td>)
      end
    end
  end
end
