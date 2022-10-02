module Mdextab
  #
  # THトークン対応クラス
  class Th
    #
    # 初期化
    #
    # @param lineno [String] THトークン出現行の行番号
    # @param attr [String] THトークンの属性
    def initialize(lineno, attr=nil)
      @lineno = lineno
      @attr = attr
      @content = ""
    end

    #
    # THトークンのコンテンツ追加
    #
    # @param content [String] THトークンのコンテンツ
    # @param condense [Boolean] 文字列化方法 true:改行を含めない false:改行を含める
    # @return [void]
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

    #
    # thの文字列化
    #
    # @return [String] HTMLのTHタグとして文字列化したもの
    def to_s
      if @attr.nil?
        %(<th>#{@content}</th>)
      else
        %(<th #{@attr}>#{@content}</th>)
      end
    end
  end
end
