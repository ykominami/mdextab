module Mdextab
  #
  # TBODYトークン対応クラス
  class Tbody
    extend Forwardable

    # @return [Integer] TBODYトークン出現行の行番号
    attr_reader :lineno

    # @!method td_append
    #   @see Td#add
    def_delegator :@td, :add, :td_append

    # @!method th_append
    #   @see Th#add
    def_delegator :@th, :add, :th_append

    #
    # 初期化
    #
    # @param lineno [String] TBODYトークン出現行の行番号
    # @param mes [Messagex] Messagexクラスのインスタンス
    def initialize(lineno, mes)
      @array = []
      @tr = nil
      @th = nil
      @td = nil
      @lineno = lineno
      @mes = mes
    end

    #
    # THの追加
    #
    # @param lineno [String] THトークン出現行の行番号
    # @param content [String] THトークンのコンテンツ
    # @param nth [Integer] THトークンの出現順番
    # @param attr [String] THトークンの属性
    # @param condense [Boolean] 文字列化方法 true:改行を含めない false:改行を含める
    # @return [void]
    def add_th(lineno, content, nth, attr, condense)
      # TRトークンが出現せずにTHトークンが出現したら、仮想的なTRトークンが出現したとみなす
      if nth == 1
        @tr = Tr.new(lineno)
        @array << @tr
      end
      @th = Th.new(lineno, attr)
      @th.add(content, condense)
      @tr.add(@th)
    end

    #
    # TDの追加
    #
    # @param lineno [String] TDトークン出現行の行番号
    # @param content [String] TDトークンのコンテンツ
    # @param nth [Integer] TDトークンの出現順番
    # @param attr [String] TDトークンの属性
    # @param condense [Boolean] 文字列化方法 true:改行を含めない false:改行を含める
    # @return [void]
    def add_td(lineno, content, nth, attr, condense)
      @mes.output_debug("content=#{content}|nth=#{nth}|attr=#{attr}")
      # TRトークンが出現せずにTDトークンが出現したら、仮想的なTDトークンが出現したとみなす
      if nth == 1
        @tr = Tr.new(lineno)
        @array << @tr
      end
      @td = Td.new(lineno, attr)
      @td.add(content, condense)
      @tr.add(@td)
    end

    #
    # TBODYの追加終了
    #
    # @return [void]
    def finish
      @tr = nil
    end

    #
    # tbodyの文字列化
    #
    # @return [String] HTMLのTBODYタグとして文字列化したもの
    def to_s
      ["<tbody>", @array.map(&:to_s), "</tbody>"].join("\n")
    end
  end
end
