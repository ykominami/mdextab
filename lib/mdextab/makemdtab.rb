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
      @erubyVariableStr=erubyVariableStr
      @erubyStaticStr=erubyStaticStr
      @outputfname=opts["output"]
      @objByYaml=objByYaml

      @exit_cannot_find_file=1
      @exit_cannot_write_file=2

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
      @mes.addExitCode("EXIT_CODE_ILLEGAL_DATAOP")
      Filex.setup(@mes)

      begin
        @output = File.open(@outputfname, 'w')
      rescue IOError => ex
        mes2 = "Can't write #{@outputfname} 1"
        @mes.outputFatal(mes2)
        @mes.outputException(ex)
        exit(@mes.ec("EXIT_CODE_CANNOT_WRITE_FILE"))
      rescue SystemCallError => ex
        mes2 = "Can't write #{@outputfname} 2"
        @mes.outputFatal(mes2)
        @mes.outputException(ex)
        exit(@mes.ec("EXIT_CODE_CANNOT_WRITE_FILE"))
      end
    end

    def self.create(opts, fnameVariable, fnameStatic, rootSettingfile, mes)
      Filex.setup(mes)

      unless File.exist?(opts["output"])
        mes.outputFatal("Can't find #{opts["output"]}")
        exit(mes.ec("EXIT_CODE_CANNOT_FIND_FILE"))
      end
      objByYaml = Filex.checkAndLoadYamlfile(rootSettingfile, mes)

      strVariable=Filex.checkAndLoadFile(fnameVariable, mes) if fnameVariable
      strStatic=["<% " , Filex.checkAndExpandFile(fnameStatic, objByYaml, mes), "%>"].join("\n") if fnameStatic
      
       Makemdtab.new(opts, strVariable, strStatic, objByYaml, mes)
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
        objy={"parentDir" => '%q!' + Dir.pwd + '!' }
        erubyExanpdedStr=""
        if @erubyVariableStr 
          if @erubyVariableStr.empty?
            erubyExanpdedStr=""
          else
            erubyExanpdedStr=["<% ", Filex.expandStr(@erubyVariableStr, objy, @mes), " %>"].join("\n")
          end
        end
        mbstr=Filex.checkAndLoadFile(mdfname, @mes)
        dx = [erubyExanpdedStr, @erubyStaticStr, mbstr].join("\n")
        objz=auxhs.merge(objx)
        if dx.strip.empty?
          puts "empty mdfname=#{mdfname}"
        else
          array=[Filex.expandStr(dx, objz, @mes, {"mdfname" => mdfname})]
        end
      when :YAML_TO_MD
        @mes.outputDebug(":YAML_TO_MD")
        @mes.outputDebug("datayamlfname=#{datayamlfname}")
        @mes.outputDebug("objx=#{objx}")

        objy=Filex.checkAndExpandYamlfile(datayamlfname, objx, @mes)
        @mes.outputDebug("objy=#{objy}")
        @mes.outputDebug("templatefile=#{templatefile}")

        erubystr=Filex.checkAndLoadFile(templatefile, @mes)
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

    def postProcess
      @output.close if @output
      @output = nil
    end
  end
end
