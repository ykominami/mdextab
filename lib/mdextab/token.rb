module Mdextab
  #
  # Tokenクラス
  class Token
    # @return [Symbol] トークンの種類
    attr_reader :kind
    # @return [Hash] トークンのオプション
    attr_reader :opt

    #
    # 初期化
    #
    # @param mes [Messagex] Messagexクラスのインスタンス
    def initialize(mes)
      @mes = mes
      @token_struct = Struct.new(:kind, :opt)
    end

    #
    # トークンの生成
    #
    # @param kind [Symbol] 生成するトークンの種類
    # @param opt [Hash] 生成するトークンのオプション設定
    # @option opt [String] :content トークンの内容
    # @option opt [Integer] :lineno トークン出現行の行番号
    # @option opt [Integer] :nth ":"の並び文字列長
    # @option opt [String,nil] :attr トークンの属性またはnil(属性が存在しない場合)
    # @option opt [Integer] :lineno トークン出現行の行番号
    # @return [Struct] 生成されたトークン
    def create_token(kind, opt={})
      @token_struct.new(kind, opt)
    end

    #
    # TABLE_STARTトークンの取得
    #
    # @param line [String] 現在行
    # @param lineno [Integer] 現在行の行番号
    # @return [Struct,nil] 生成されたトークンまたはnil(トークンが存在しない場合)
    # @note TABLE_STARTトークンが存在するかもしれないと判断されたときに呼ばれる
    def get_token_table_start(line, lineno)
      if /^\s*<table>\s*$/.match?(line)
        ret = create_token(:TABLE_START, { lineno: lineno })
      elsif (m = /^\s*<table\s+(.+)>\s*$/.match(line))
        ret = create_token(:TABLE_START, { attr: m[1], lineno: lineno })
      else
        ret = nil
      end
      ret
    end

    #
    # TBODY_STARTトークンの取得
    #
    # @param line [String] 現在行
    # @param lineno [Integer] 現在行の行番号
    # @return [Struct,nil] 生成されたトークンまたはnil(トークンが存在しない場合)
    # @note TBODY_STARTトークンが存在するかもしれないと判断されたときに呼ばれる
    def get_token_tbody_start(line, lineno)
      if /^\s*<tbody>\s*$/.match?(line)
        ret = create_token(:TBODY_START, { lineno: lineno })
      else
        ret = nil
      end
      ret
    end

    #
    # 先頭が:で始まる場合の適切なトークンの取得
    #
    # @param line [String] 現在行
    # @param lineno [Integer] 現在行の行番号
    # @param nth [Integer] 並んでいる:の個数
    # @param cont [String] 現在行の中の:の並びを区切り文字列とした場合の右側の部分
    # @return [Struct,nil] 生成されたトークンまたはnil(トークンが存在しない場合)
    # @note 先頭が:のときに呼ばれる
    def get_token_colon_start(line, lineno, nth, cont)
      if (m = /^th(.*)/.match(cont))
        cont2 = m[1]
        if (m2 = /^\s(.*)/.match(cont2))
          cont3 = m2[1]
          if (m3 = /^([^<]*)>(.*)$/.match(cont3))
            attr = m3[1]
            cont4 = m3[2]
            ret = create_token(:TH, { nth: nth, attr: attr, content: cont4, lineno: lineno })
          else
            # error
            # ret = nil
            ret = create_token(:ELSE, { nth: nth, attr: nil, content: cont, lineno: lineno })
          end
        elsif (m = /^>(.*)$/.match(cont2))
          cont3 = m[1]
          ret = create_token(:TH, { nth: nth, attr: nil, content: cont3, lineno: lineno })
        else
          ret = create_token(:ELSE, { nth: nth, attr: nil, content: cont, lineno: lineno })
        end
      elsif (m = /^([^<]*)>(.*)$/.match(cont))
        attr = m[1]
        cont2 = m[2]
        ret = create_token(:TD, { nth: nth, attr: attr, content: cont2, lineno: lineno })
      else
        ret = create_token(:TD, { nth: nth, attr: attr, content: cont, lineno: lineno })
      end
      ret
    end

    #
    # TABLE_ENDトークンの取得
    #
    # @param line [String] 現在行
    # @param lineno [Integer] 現在行の行番号
    # @return [Struct,nil] 生成されたトークンまたはnil(トークンが存在しない場合)
    # @note TABLE_ENDトークンが存在するかもしれないと判断されたときに呼ばれる
    def get_token_table_end(line, lineno)
      if %r{^\s*</table>\s*$}.match?(line)
        ret = create_token(:TABLE_END, { lineno: lineno })
      else
        ret = nil
      end
      ret
    end

    #
    # トークンの取得
    #
    # @param line [String] 現在行
    # @param lineno [Integer] 現在行の行番号
    # @return [Struct,nil] 生成されたトークンまたはnil(トークンが存在しない場合)
    def get_token(line, lineno)
      case line
      when /^\*S(.+)$/
        content = Regexp.last_match(1)
        ret = create_token(:STAR_START, { content: content, lineno: lineno })
      when /^\*E(.+)$/
        content = Regexp.last_match(1)
        ret = create_token(:STAR_END, { content: content, lineno: lineno })
      when /^\s*<table/
        ret = get_token_table_start(line, lineno)
      when /^\s*<tbody/
        ret = get_token_tbody_start(line, lineno)
      when /^\s*(\:+)(.*)$/
        nth = Regexp.last_match(1).size
        cont = Regexp.last_match(2)
        ret = get_token_colon_start(line, lineno, nth, cont)
      when %r{^\s*</table}
        ret = get_token_end_table(line, lineno)
      when %r{^\s*</tbody}
        if %r{^\s*</tbody>\s*$}.match?(line)
          ret = create_token(:TBODY_END, { lineno: lineno })
        else
          @mes.output_debug("E001 line=#{line}")
          ret = nil
        end
      else
        ret = create_token(:ELSE, { content: line, lineno: lineno })
      end

      ret
    end
  end
end
