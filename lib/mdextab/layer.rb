module Mdextab
  #
  # 入れ子のTableにを管理するレイヤークラス
  class Layer
    # 入れ子のレイヤーからリターンしたかを示す
    # @return [Boolean]
    attr_accessor :return_from_nested_layer
    # 現在のレイヤー
    # @return [Layer]
    attr_accessor :cur_layer
    # レイヤーの階層数
    # @return [Integer]
    attr_accessor :size

    #
    # 初期化
    #
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @param output [IO] 出力先
    def initialize(mes, output)
      @mes = mes
      @output = output
      @return_from_nested_layer = false

      @layer_struct = Struct.new(:table, :star, :cur_state, :fname, :lineno)
      @cur_layer = nil
      @layers = []
    end

    # @overload cur_state=(val)
    # カレントレイヤーの状態を設定
    # @param val [Symbol]
    def cur_state=(val)
      # raise if val.class != Symbol
      @cur_layer.cur_state = val
    end

    # @overload cur_state
    # カレントレイヤーの状態を設定
    # @return [Symbol] 現在の状態
    def cur_state
      raise if @cur_layer.cur_state.class != Symbol
      @cur_layer.cur_state
    end

    # @overload table=(val)
    # カレントレイヤーのtableを設定
    # @param val [Table] カレントレイヤーのtable
    def table=(val)
      @cur_layer.table = val
    end

    # @overload tablee
    # カレントレイヤーのtableを取得
    # @return [Table] カレントレイヤーのtable
    def table
      @cur_layer.table
    end

    # @overload star=(val)
    # カレントレイヤーのstarの存在の有無を設定
    # @param val [Boolean] カレントレイヤーのstarの存在の有無 true:starが存在 false:startが存在しない
    def star=(val)
      @cur_layer.star = val
    end

    # @overload star=(val)
    # カレントレイヤーのstarの存在の有無を取得
    # @return [Boolean] カレントレイヤーのstaの存在の有無 true:starが存在 false:startが存在しない
    def star
      @cur_layer.star
    end

    #
    # 新しいレイヤーの追加
    #
    # @param fname [String] 構文解析対象のMarkdownファイル名
    # @param lineno [String] TABLE_STARTトークン出現行の行番号
    # @return [Symbol] テーブル拡張向け構文解析での状態
    def add_layer(fname, lineno, state=:START)
      new_layer = @layer_struct.new(nil, nil, nil, fname, lineno)
      @layers << new_layer
      @size = @layers.size
      # raise if state.class != Symbol
      new_layer.cur_state = state
      if @cur_layer
        new_layer.star = @cur_layer.star
      else
        new_layer.star = false
      end
      @cur_layer = new_layer
    end

    #
    # カレントレイヤーを取り出して返す
    #
    # @return [Layer] 取り出されたカレントレイヤー
    def pop_layer
      tmp_ = @layers.pop
      @size = @layers.size
      @cur_layer = @layers.last

      tmp_
    end

    #
    # 1つ前のレイヤーを返す
    #
    # @return [Layer,nil] 1つ前のレイヤーまたはnil
    #   (1つ前のレイヤーが存在しない場合)
    def peek_prev_layer
      return nil unless @layers.size > 1

      @layers[@layers.size - 2]
    end

    #
    # 入れ子のTABLE_STARTトークンとトークン出現行の処理
    #
    # @param token [Token] 読み込んだトークン
    # @param lineno [Integer] トークン出現行の行番号
    # @param fname [String] 構文解析対象のMarkdownファイル名
    # @return [void]
    def process_nested_table_start(token, lineno, fname)
      # TBODYトークンが出現する前にTABLE_STARTトークンが出現した場合、仮想的なTBODYトークンが出現したとみなす
      if table.tbody.nil?
        table.add_tbody(lineno)
      end
      @mes.output_debug("B process_nested_table_start 1 @cur_layer.table=#{@cur_layer.table.object_id} token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} cur_state=#{@cur_layer.cur_state}")
      # 新しいレイヤーを追加して、それをカレントレイヤーとし、カレントレイヤーにTableを追加する
      add_layer(fname, lineno, :OUT_OF_TABLE)
      @cur_layer.table = Table.new(token.opt[:lineno], @mes, token.opt[:attr])
      @mes.output_debug("process_nested_table_start 3 token.kind=#{token.kind} cur_state=#{@cur_layer.cur_state}")
    end

    #
    # TABLE_ENDトークンの処理
    #
    # @param token [Token] 読み込んだトークン
    # @return [void]
    def process_table_end(token)
      prev_layer = peek_prev_layer
      return unless prev_layer

      # 一つ前のレイヤーが存在すれば、入れ子のTABLE_ENDトークンとして処理する
      process_table_end_for_prev_env(token)
    end

    #
    # 入れ子のTABLE_ENDトークンの処理
    #
    # @param token [Token] 読み込んだトークン
    # @return [void]
    # @note tokenはデバッグ出力、エラー出力に使う
    def process_table_end_for_prev_env(token)
      tmp_table = @cur_layer.table
      pop_layer
      @return_from_nested_layer = true

      # pop_layerを呼んだ後なので、カレントレイヤーはメソッド呼び出し時より一つ前のレイヤー
      case @cur_layer.cur_state
      when :IN_TD
        @cur_layer.table.td_append(tmp_table, @cur_layer.star)
      when :IN_TD_NO_TBODY
        @cur_layer.table.td_append(tmp_table, @cur_layer.star)
      when :IN_TH
        @cur_layer.table.th_append(tmp_table, @cur_layer.star)
      when :IN_TH_NO_TBODY
        @cur_layer.table.th_append(tmp_table, @cur_layer.star)
      when :IN_TABLE
        if @cur_layer.table.nil?
          @mes.output_debug("In process_nested_table_env_for_prev_env: table=nil token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} cur_state=#{@cur_layer.cur_state}")
          raise
        end
        @cur_layer.table.add(tmp_table)
      when :IN_TABLE_BODY
        @cur_layer.table.add(tmp_table)
      when :START
        @mes.output_debug("In process_nested_table_env_for_prev_env: table=nil token.kind=#{token.kind} token.opt[:lineno]=#{token.opt[:lineno]} cur_state=#{@cur_layer.cur_state}")
        raise
      else
        v = @cur_layer.cur_state || "nil"
        @mes.output_fatal("E100 cur_state=#{v}")
        @mes.output_fatal("table=#{@cur_layer.table}")
        @mes.output_fatal("IllegalState(#{@cur_layer.cur_state} in process_table_end(#{token})")
        exit(@mes.ec("EXIT_CODE_TABLE_END"))
      end
    end

    #
    # 全レイヤーの状態検査
    #
    # @param fname [String] 構文解析対象のMarkdownファイル名
    # @return [void]
    # @note fnameはデバッグ出力、エラー出力に使う
    def check_layers(fname)
      case @cur_layer.cur_state
      when :OUT_OF_TABLE
        if @layers.size > 1
          @mes.output_fatal("illeagal nested env after parsing|:OUT_OF_TABLE")
          @mes.output_fatal("@layers.size=#{@layers.size} :TABLE_START #{fname} #{table.lineno}")
          @layers.map {|x| @mes.output_debug("== @layers.cur_state=#{x.cur_state} :TABLE_START #{fname} #{x.table.lineno}") }
          @mes.output_debug("== table")
          @mes.output_info(table)
          exit(@mes.ec("EXIT_CODE_EXCEPTION"))
        end
      when :START
        if @layers.size > 1
          @mes.output_fatal("illeagal nested env after parsing|:START")
          @mes.output_fatal("@layers.size=#{@layers.size}")
          @layers.map {|x| @mes.output_error("== @layers.cur_state=#{x.cur_state} :TABLE_START #{fname} #{x.table.lineno}") }
          @mes.output_error("== table")
          @mes.output_error(table)
          exit(@mes.ec("EXIT_CODE_EXCEPTION"))
        end
      else
        @mes.output_fatal("illeagal state after parsing(@cur_layer.cur_state=#{@cur_layer.cur_state}|fname=#{fname}")
        @mes.output_fatal("@layers.size=#{@layers.size}")
        @mes.output_error("== cur_state=#{@cur_layer.cur_state}")
        @layers.map {|x| @mes.output_error("== @layers.cur_state=#{x.cur_state} #{fname}:#{x.table.lineno}") }
        @mes.output_error("")
        exit(@mes.ec("EXIT_CODE_ILLEAG<AL_STATE"))
      end
    end
  end
end
