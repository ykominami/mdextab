module Mdextab
  require "digest"
  require "pp"
  require "filex"

  class Makemdtab
    def initialize(opts, eruby_variable_str, eruby_static_str, obj_by_yaml, mes=nil)
      @yamlfiles = {}
      @str_yamlfiles = {}
      @str_mdfiles = {}
      @str_erubyfiles = {}
      @dataop = opts["dataop"]
      @datayamlfname = opts["data"]
      @eruby_variable_str = eruby_variable_str
      @eruby_static_str = eruby_static_str
      @outputfname = opts["output"]
      @obj_by_yaml = obj_by_yaml

      @exit_cannot_find_file = 1
      @exit_cannot_write_file = 2

      @mes = mes
      unless @mes
        if opts["debug"]
          @mes = Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, :debug)
        elsif opts["verbose"]
          @mes = Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, :verbose)
        else
          @mes = Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0)
        end
      end
      @mes.addExitCode("EXIT_CODE_ILLEGAL_DATAOP")
      Filex::Filex.setup(@mes)

      @output = @mes.excFileWrite(@outputfname) { File.open(@outputfname, "w") }
    end

    def self.create(opts, fname_variable, fname_static, root_settingfile, mes)
      Filex::Filex.setup(mes)

      unless File.exist?(opts["output"])
        mes.outputFatal("Can't find #{opts['output']}")
        exit(mes.ec("EXIT_CODE_CANNOT_FIND_FILE"))
      end
      obj_by_yaml = Filex::Filex.check_and_load_yamlfile(root_settingfile, mes)

      str_variable = Filex::Filex.check_and_load_file(fname_variable, mes) if fname_variable
      str_static = ["<% ", Filex::Filex.check_and_expand_file(fname_static, obj_by_yaml, mes), "%>"].join("\n") if fname_static

      Makemdtab.new(opts, str_variable, str_static, obj_by_yaml, mes)
    end

    def make_md2(root_dir, templatefile=nil, auxhs={})
      objx = @obj_by_yaml.merge(auxhs)
      case @dataop
      when :FILE_INCLUDE
        array = load_file_include(root_dir, @datayamlfname, objx)
      when :YAML_TO_MD
        unless templatefile
          @mes.outputFatal("Not specified templatefile")
          exit(@mes.ec("EXIT_CODE_NOT_SPECIFIED_FILE"))
        end
        if templatefile.strip.empty?
          @mes.outputFatal("Not specified templatefile")
          exit(@mes.ec("EXIT_CODE_NOT_SPECIFIED_FILE"))
        end

        array = load_yaml_to_md(@datayamlfname, templatefile, objx)
      else
        array = []
      end
      array.map {|x| @mes.excFileWrite(@outputfname) { @output.puts(x) } }
    end

    def load_file_include(root_dir, datayamlfname, objx)
      mdfname = datayamlfname
      objy = { "parentDir" => "%q!" + root_dir + "!" }
      eruby_exanpded_str = ""
      if @eruby_variable_str
        if @eruby_variable_str.empty?
          eruby_exanpded_str = ""
        else
          eruby_exanpded_str = ["<% ", Filex::Filex.expand_str(@eruby_variable_str, objy, @mes), " %>"].join("\n")
        end
      end
      mbstr = Filex::Filex.check_and_load_file(mdfname, @mes)
      dx = [eruby_exanpded_str, @eruby_static_str, mbstr].join("\n")
      if dx.strip.empty?
        puts "empty mdfname=#{mdfname}"
      else
        array = [Filex::Filex.expand_str(dx, objx, @mes, { "mdfname" => mdfname })]
      end

      array
    end

    def load_yaml_to_md(datayamlfname, templatefile, objx)
      @mes.outputDebug("datayamlfname=#{datayamlfname}")
      @mes.outputDebug("objx=#{objx}")

      objy = Filex::Filex.check_and_expand_yamlfile(datayamlfname, objx, @mes)
      @mes.outputDebug("objy=#{objy}")
      @mes.outputDebug("templatefile=#{templatefile}")

      erubystr = Filex::Filex.check_and_load_file(templatefile, @mes)
      @mes.outputDebug("erubystr=#{erubystr}")
      dx = [@eruby_static_str, erubystr].join("\n")
      @mes.outputDebug("dx=#{dx}")
      array = [Filex::Filex.expand_str(dx, objy, @mes, { "datayamlfname" => datayamlfname, "templatefile" => templatefile })]

      array
    end

    def post_process
      @mes.excFileClose(@outputfname) { @output&.close }
      @output = nil
    end
  end
end
