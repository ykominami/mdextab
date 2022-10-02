# テーブル拡張Markdownモジュール
module Mdextab
  require "digest"
  require "pp"
  require "filex"

  #
  # テーブル拡張Markdown生成クラス
  class Makemdtab
    #
    # 初期化
    #
    # @param opts [Hash] オプション
    # @option opts [Symbol] :debug Messagexクラスのインスタンスに与えるデバッグモード
    # @param eruby_variable_str [String] 2回の置き換えが必要なeRubyスクリプト
    # @param eruby_static_str [String] 1回の置き換えが必要なeRubyスクリプト
    # @param obj_by_yaml [Hash] eRubyスクリプト向け置換用ハッシュ
    # @param mes [Messagex] Messagexクラスのインスタンス
    def initialize(opts, eruby_variable_str, eruby_static_str, obj_by_yaml, mes=nil)
      @dataop = opts[:dataop]
      @datayamlfname = opts[:data]
      @eruby_variable_str = eruby_variable_str
      @eruby_static_str = eruby_static_str
      @outputfname = opts[:output]
      @obj_by_yaml = obj_by_yaml

      @mes = mes
      @mes ||= if opts[:debug]
                 Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, :debug)
               elsif opts[:verbose]
                 Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, :verbose)
               else
                 Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0)
               end
      @mes.add_exitcode("EXIT_CODE_ILLEGAL_DATAOP")
      Filex::Filex.setup(@mes)

      @output = @mes.exc_file_write(@outputfname) { File.open(@outputfname, "w") }
    end

    #
    # ファイルから生成（使われていない？）
    #
    # @param opts [Hash] オプション
    # @option opts [String] :debug Messagexクラスのインスタンスに与えるデバッグモード
    # @option opts [IO] :output 出力先IO
    # @param fname_variable [String] 2回の置き換えが必要なeRubyスクリプトファイル名
    # @param fname_static [String] 1回の置き換えが必要なeRubyスクリプトファイル名
    # @param root_settingfile [String] eRubyスクリプト向け置換用YAML形式ファイル名
    # @param mes [Messagex] Messagexクラスのインスタンス
    # @return [Makemdtab]
    def self.create(opts, fname_variable, fname_static, root_settingfile, mes)
      Filex::Filex.setup(mes)

      unless File.exist?(opts[:output])
        mes.output_fatal("Can't find #{opts[:output]}")
        exit(mes.ec("EXIT_CODE_CANNOT_FIND_FILE"))
      end
      obj_by_yaml = Filex::Filex.check_and_load_yamlfile(root_settingfile, mes)

      str_variable = Filex::Filex.check_and_load_file(fname_variable, mes) if fname_variable
      str_static = ["<% ", Filex::Filex.check_and_expand_file(fname_static, obj_by_yaml, mes), "%>"].join("\n") if fname_static

      Makemdtab.new(opts, str_variable, str_static, obj_by_yaml, mes)
    end

    #
    # YAML形式ファイルからテーブル拡張Markdown形式ファイルを生成
    #
    # @param root_dir [String] ルートディレクト(templatefileが示す相対パスの起点)
    # @param templatefile [String,nil] テーブル拡張Makrdown形式の変換元YAML形式ファイルへの相対パス
    # @param auxhs [Hash] eRubyスクリプト向け置換用ハッシュ（@obj_by_yamlにマージする）
    # @return [void]
    def make_md2(root_dir, templatefile=nil, auxhs={})
      # 補助的な置換用ハッシュを@obj_by_yamlにマージする
      objx = @obj_by_yaml.merge(auxhs)
      case @dataop
      when :FILE_INCLUDE
        # ハッシュobjxは、メソッドfileReadの実引数を、読み込むべきファイルの相対パスに変換する定義を含んでいる
        array = load_file_include(root_dir, @datayamlfname, objx)
      when :YAML_TO_MD
        unless templatefile
          @mes.output_fatal("Not specified templatefile")
          exit(@mes.ec("EXIT_CODE_NOT_SPECIFIED_FILE"))
        end
        if templatefile.strip.empty?
          @mes.output_fatal("Not specified templatefile")
          exit(@mes.ec("EXIT_CODE_NOT_SPECIFIED_FILE"))
        end
        # YAMLファイルを、eRubyスクリプトであるtemplatefileを用いてテーブル拡張Markdown形式に変換する
        array = load_yaml_to_md(@datayamlfname, templatefile, objx)
      else
        array = []
      end
      array.map { |x| @mes.exc_file_write(@outputfname) { @output.puts(x) } }
    end

    #
    # eRubyスクリプト取り込み処理
    #
    # @param root_dir [String] ルートディレクト(eruby_fnameが示す相対パスの起点)
    # @param eruby_fname [String] fileReadメソッド呼び出しを含むeRubyスクリプトファイル名
    # @param objx [Hash] eRubyスクリプト向け置換用ハッシュ
    # @return [Array<String>] 指定ファイルを取り込んで展開した結果の文字列の配列(ただし要素は1個のみ)
    def load_file_include(root_dir, eruby_fname, objx)
      # eruby_fnameはfileReadメソッド呼び出しを含むeRubyスクリプトファイル
      # fileReadメソッドは、引数を読み込むべきファイルへのパスに変換して、ファイルを読み込む

      # fileReadメソッドで参照するparentDirという変数に、root_dirの値を割り当てる
      objy = { "parentDir" => "%q!#{root_dir}!" }
      # @eruby_variable_strにfileReadメソッドの定義が含まれる
      eruby_exanpded_str = ""
      if @eruby_variable_str
        eruby_exanpded_str = if @eruby_variable_str.empty?
                               ""
                             else
                               # 変数parent_dirをobjyで定義された値に置換て、fileReadメソッドの定義を完成させる
                               # 置換して得られた文字列を、もう一度eRubyスクリプトにする
                               ["<% ", Filex::Filex.expand_str(@eruby_variable_str, objy, @mes), " %>"].join("\n")
                             end
      end
      # fileReadメソッド呼び出しを含むeRubyスクリプトファイルを読み込む
      mbstr = Filex::Filex.check_and_load_file(eruby_fname, @mes)
      # fileReadメソッド定義とそれ以外のメソッド定義と読み込んだeRubuスクリプトを連結して一つのeRubyスクリプトにする
      dx = [eruby_exanpded_str, @eruby_static_str, mbstr].join("\n")
      if dx.strip.empty?
        puts "empty eruby_fname=#{eruby_fname}"
      else
        # ハッシュobjxは、メソッドfileReadの実引数を、読み込むべきファイルの相対パスに変換する定義を含んでいる
        # Filex::Filex.expand_strに渡すハッシュは、エラーメッセージに用いるためのものであり、eRubyスクリプトとは無関係である
        array = [Filex::Filex.expand_str(dx, objx, @mes, { "eruby_fname" => eruby_fname })]
      end

      array
    end

    #
    # eRubyスクリプトファイルでもあるYAML形式ファイルからテーブル拡張Markdown形式に変換
    #
    # @param datayamlfname [String] eRubyスクリプトファイルでもあるYAML形式ファイル
    # @param templatefile [String] YAML形式をテーブル拡張Markdwon形式に変換するeRubyスクリプトファイル
    # @param objx [Hash] eRubyスクリプト向け置換用ハッシュ
    # @return [Array<String>] 変換されたテーブル拡張Markdwon形式の文字列の配列(ただし要素は1個のみ)
    def load_yaml_to_md(datayamlfname, templatefile, objx)
      @mes.output_debug("datayamlfname=#{datayamlfname}")
      @mes.output_debug("objx=#{objx}")

      # いったんeRubyスクリプトファイルとして読み込んで置換したあと、YAML形式として再度読み込み、Rubyのハッシュに変換する
      objy = Filex::Filex.check_and_expand_yamlfile(datayamlfname, objx, @mes)
      @mes.output_debug("objy=#{objy}")
      @mes.output_debug("templatefile=#{templatefile}")

      # YAML形式をテーブル拡張Markdwon形式に変換するeRubyスクリプトファイルを読み込む
      erubystr = Filex::Filex.check_and_load_file(templatefile, @mes)
      @mes.output_debug("erubystr=#{erubystr}")
      # メソッド定義を含むeRubyスクリプトとtemplatefileを一つのeRubyスクリプトにする
      dx = [@eruby_static_str, erubystr].join("\n")
      @mes.output_debug("dx=#{dx}")
      # eRubyスクリプトにdatayamlfnameの内容を置換用ハッシュとして適用して、テーブル拡張Markdown形式に変換する
      # Filex::Filex.expand_strに渡すハッシュは、エラーメッセージに用いるためのものであり、eRubyスクリプトとは無関係である
      [Filex::Filex.expand_str(dx, objy, @mes, { "datayamlfname" => datayamlfname, "templatefile" => templatefile })]
    end

    #
    # 終了処理
    #
    # @return [void]
    def post_process
      @mes.exc_file_close(@outputfname) { @output&.close }
      @output = nil
    end
  end
end
