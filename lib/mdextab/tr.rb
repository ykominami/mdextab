module Mdextab
  #
  # TRトークン対応クラス
  class Tr
    #
    # 初期化
    #
    # @param lineno [String] TRトークン出現行の行番号
    def initialize(lineno)
      @lineno = lineno
      @array = []
    end

    #
    # TRトークンのコンテンツ追加
    #
    # @param content [String] TRトークンのコンテンツ
    # @return [void]
    def add(cont)
      @array << cont
    end

    #
    # trの文字列化
    #
    # @return [String] HTMLのTRタグとして文字列化したもの
    def to_s
      ["<tr>", @array.map(&:to_s), "</tr>"].join("\n")
    end
  end
end
