module Mdextab
  require 'digest'
  require 'pp'

  class Makemdtab

    def initialize(opts, erubyVariableStr, erubyStaticStr, objByYaml, mes=nil)
      @yamlfiles={}
      @str_yamlfiles={}
      @str_mdfiles={}
      @str_erubyfiles={}
      @dataop=opts["dataop"]
      @datayamlfname=opts["data"]
      @yamlop=opts["yamlop"]
      @erubyVariableStr=erubyVariableStr
      @erubyStaticStr=erubyStaticStr
      @outputfname=opts["output"]
      @objByYaml=objByYaml

      @exit_cannot_find_file=1
      @exit_cannot_write_file=2

      @erubies = {}

      @mes=mes
      unless @mes
        if opts["debug"]
          @mes=Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, :debug)
        elsif opts["verbose"]
          @mes=Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0, :verbose)
        else
          @mes=Messagex::Messagex.new("EXIT_CODE_NORMAL_EXIT", 0)
        end
      end
      @mes.addExitCode("EXIT_CODE_CANNOT_WRITE_FILE")
      @mes.addExitCode("EXIT_CODE_ILLEGAL_DATAOP")
      Filex.setup(@mes)

      begin
        @output = File.open(@outputfname, 'w')
      rescue RuntimeError => ex
        mes2 = "Can't write #{@outputfname}"
        @mes.outputFatal(mes2)
        exit(@mes.ec("EXIT_CODE_CANNOT_WRITE_FILE"))
      end
    end

    def makeMd2(templatefile=nil, auxhs={})
      load2(@dataop, @datayamlfname, templatefile, auxhs).map{|x|
        @output.puts(x)
      }
    end

    def load2(dataop, datayamlfname, templatefile, auxhs)
      objx=@objByYaml.merge(auxhs)
      case dataop
      when :FILE_INCLUDE
        mdfname=datayamlfname
        objy={"parentDir" => '%q!' + ENV['MDEXTAB_MAKE'] + '!' }
        erubyExanpdedStr=["<% ", Filex.expandStr(@erubyVariableStr, objy, @mes), " %>"].join("\n")

        mdstr=checkAndLoadMdfile(mdfname)
        dx = [erubyExanpdedStr, @erubyStaticStr, mdstr].join("\n")
        objz=auxhs.merge(objx)
        array=[Filex.expandStr(dx, objz, @mes, {"mdfname" => mdfname})]
      when :YAML_TO_MD
        @mes.outputDebug(":YAML_TO_MD")
        @mes.outputDebug("datayamlfname=#{datayamlfname}")
        @mes.outputDebug("objx=#{objx}")

        objy=checkAndExpandYamlfile(datayamlfname, objx)
        @mes.outputDebug("objy=#{objy}")
        @mes.outputDebug("templatefile=#{templatefile}")
        erubystr=checkAndLoadErubyfile(templatefile)
        @mes.outputDebug("erubystr=#{erubystr}")
        dx = [@erubyStaticStr, erubystr].join("\n")
        @mes.outputDebug("dx=#{dx}")
        array=[Filex.expandStr(dx, objy, @mes, {"datayamlfname" => datayamlfname , "templatefile" => templatefile})]
      else
        @mes.outputFatal("illegal dataop(#{dataop})")
        exit(@mes.ec("EXIT_CODE_ILLEGAL_DATAOP"))
      end
      array
    end

    def checkAndLoadErubyfile(erubyfname)
      unless @str_erubyfiles[erubyfname]
        @str_erubyfiles[erubyfname]=Filex.checkAndLoadFile(erubyfname, @mes)
      end
      @str_erubyfiles[erubyfname]
    end

    def checkAndExpandErubyfile(erubyfname, objx)
      unless @str_erubyfiles[yamlfname]
        @str_erubyfiles[yamlfname]=Filex.checkAndExpandFile(erubyfname, objx, @mes)
      end
      @str_erubyfiles[erubyfname]
    end

    def checkAndExpandYamlfile(yamlfname, objx)
      unless @str_yamlfiles[yamlfname]
        @str_yamlfiles[yamlfname]=Filex.checkAndExpandYamlfile(yamlfname, objx, @mes)
      end
      @str_yamlfiles[yamlfname]
    end

    def checkAndLoadMdfile(mdfname)
      unless @str_mdfiles[mdfname]
        str=Filex.checkAndLoadFile(mdfname, @mes)
        @str_mdfiles[mdfname]=str
      end
      @str_mdfiles[mdfname]
    end

    def postProcess
      @output.close if @output
      @output = nil
    end
  end
end
