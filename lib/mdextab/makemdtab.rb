module Mdextab
  require 'digest'
  require 'pp'
  require 'filex'

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
      Filex::Filex.setup(@mes)

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
      Filex::Filex.setup(mes)

      unless File.exist?(opts["output"])
        mes.outputFatal("Can't find #{opts["output"]}")
        exit(mes.ec("EXIT_CODE_CANNOT_FIND_FILE"))
      end
      objByYaml = Filex::Filex.checkAndLoadYamlfile(rootSettingfile, mes)

      strVariable=Filex::Filex.checkAndLoadFile(fnameVariable, mes) if fnameVariable
      strStatic=["<% " , Filex::Filex.checkAndExpandFile(fnameStatic, objByYaml, mes), "%>"].join("\n") if fnameStatic
      
       Makemdtab.new(opts, strVariable, strStatic, objByYaml, mes)
    end

    def makeMd2(templatefile=nil, auxhs={})
      objx=@objByYaml.merge(auxhs)
      case @dataop
      when :FILE_INCLUDE
        array=loadFileInclude(@datayamlfname, objx)
      when :YAML_TO_MD
        unless templatefile
          @mes.outputFatal("Not specified templatefile")
          exit(@mes.ec("EXIT_CODE_NOT_SPECIFIED_FILE"))
        end
        if templatefile.strip.empty?
          @mes.outputFatal("Not specified templatefile")
          exit(@mes.ec("EXIT_CODE_NOT_SPECIFIED_FILE"))
        end
        array=loadYamlToMd(@datayamlfname, templatefile, objx)
      else
        array=[]
      end
      array.map{|x|
        @output.puts(x)
      }
    end

    def loadFileInclude(datayamlfname, objx)
      mdfname=datayamlfname
      objy={"parentDir" => '%q!' + Dir.pwd + '!' }
      erubyExanpdedStr=""
      if @erubyVariableStr 
        if @erubyVariableStr.empty?
          erubyExanpdedStr=""
        else
          erubyExanpdedStr=["<% ", Filex::Filex.expandStr(@erubyVariableStr, objy, @mes), " %>"].join("\n")
        end
      end
      mbstr=Filex::Filex.checkAndLoadFile(mdfname, @mes)
      dx = [erubyExanpdedStr, @erubyStaticStr, mbstr].join("\n")
      if dx.strip.empty?
        puts "empty mdfname=#{mdfname}"
      else
        array=[Filex::Filex.expandStr(dx, objx, @mes, {"mdfname" => mdfname})]
      end

      array
    end
     
    def loadYamlToMd(datayamlfname, templatefile, objx)
      @mes.outputDebug("datayamlfname=#{datayamlfname}")
      @mes.outputDebug("objx=#{objx}")
      
      objy=Filex::Filex.checkAndExpandYamlfile(datayamlfname, objx, @mes)
      @mes.outputDebug("objy=#{objy}")
      @mes.outputDebug("templatefile=#{templatefile}")
      
      erubystr=Filex::Filex.checkAndLoadFile(templatefile, @mes)
      @mes.outputDebug("erubystr=#{erubystr}")
      dx = [@erubyStaticStr, erubystr].join("\n")
      @mes.outputDebug("dx=#{dx}")
      array=[Filex::Filex.expandStr(dx, objy, @mes, {"datayamlfname" => datayamlfname , "templatefile" => templatefile})]

      array
    end

    def load2(dataop, datayamlfname, templatefile, auxhs={})
    end

    def postProcess
      @output.close if @output
      @output = nil
    end
  end
end
