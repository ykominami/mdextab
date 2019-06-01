require "forwardable"

module Mdextab
  #
  # Tableクラス
  #
  class Table
    extend Forwardable

    # @!method add_thお
    #   @see Tbody#add_th
    # @!method add_td
    #   @see Tbody#add_td
    # @!method td_append
    #   @see Tbody#td_append
    # @!method th_append
    #   @see Tbody#th_append
    # @!method add
    #   @see Tbody#add
    def_delegators :@tbody, :add_th, :add_td, :td_append, :th_append, :add

    def_delegators :@tbody, :add_th, :add_td, :td_append, :th_append, :add

    # @return 入力Markdownファイル中のTABLEトークン出現行
    attr_reader :lineno

    # @return TABLE中のTBODYトークン出現行
    attr_reader :tbody

    #
    # 初期化
    #
    # @param lineno [Integer] TABLE_STARTトークンの出現行の行番号
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @param sttr [String] TABLE_STARTトークンの属性
    def initialize(lineno, mes, attr=nil)
      @lineno = lineno
      @attr = attr
      @tbody = nil
      @mes = mes
    end

    #
    # tbodyの追加
    #
    # @param lineno [Integer] TBODY_STARTトークンまたは暗黙のtbodyの出現に係るトークンの出現行の行番号
    # @return [void]
    def add_tbody(lineno)
      @tbody = Tbody.new(lineno, @mes)
    end

    #
    # tbodyの終了処理
    #
    # @return [void]
    def tbody_end
      @tbody.finish
    end

    #
    # tableの終了処理
    #
    # @return (see #to_s)
    def table_end
      to_s
    end

    #
    # tableの文字列化
    #
    # @param debug [Symbol] デバッグ用フラグ true: デバッグ情報を付加する false: デバッグ情報を付加しない
    # @return [String] HTMLのTABLEタグとして文字列化したもの
    def to_s(debug=false)
      if @attr
        if debug
          str = %Q(<table #{@attr} lineno:#{@lineno}>)
        else
          str = %Q(<table #{@attr}>)
        end
      elsif debug
        str = %Q(<table  lineno:#{@lineno}>)
      else
        str = %Q(<table>)
      end

      [str, @tbody.to_s, "</table>"].join("\n")
    end
  end
end
