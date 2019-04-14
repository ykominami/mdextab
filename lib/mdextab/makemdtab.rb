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
      @mes.addExitCode("EXIT_CODE_CANNOT_FIND_FILE")
      @mes.addExitCode("EXIT_CODE_CANNOT_WRITE_FILE")
      @mes.addExitCode("EXIT_CODE_DATA_CLASS_ISNOT_HASH")
      @mes.addExitCode("EXIT_CODE_CANNOT_FIND_FILE_OR_EMPTY")
      @mes.addExitCode("EXIT_CODE_FILE_IS_EMPTY")
      @mes.addExitCode("EXIT_CODE_NAME_ERROR_EXCEPTION_IN_ERUBY")
      @mes.addExitCode("EXIT_CODE_ERROR_EXCEPTION_IN_ERUBY")

      Filex.setup(@mes)

      begin
        @output = File.open(@outputfname, 'w')
      rescue RuntimeError => ex
        mes2 = "Can't write #{@outputfname}"
        @mes.outputFatal(mes2)
        exit(@mes.exitCode["EXIT_CODE_CANNOT_WRITE_FILE"])
      end
    end

    def makeMd2(templatefile=nil, auxhs={})
      load2(@dataop, @datayamlfname, templatefile, auxhs).map{|x|
        @output.puts(x)
      }
    end

    def makeMd(auxhs={})
      load(@dataop, @datayamlfname, @yamlop, @auxyamlfname, @yamlfname, @erubyfnames, auxhs).map{|x|
        @output.puts(x)
      }
    end

    def load2(dataop, datayamlfname, templatefile, auxhs)
      objx=@objByYaml.merge(auxhs)
      case @dataop
      when :FILE_INCLUDE
        mdfname=datayamlfname
        objy={"parentDir" => '%q!' + ENV['MDEXTAB_MAKE'] + '!' }
        erubyExanpdedStr=["<%= ", Filex.expandStr(@erubyVariableStr, objy, @mes), " %>"].join("\n")

        mdstr=checkAndLoadMdfile(mdfname)
        dx = [erubyExanpdedStr, @erubyStaticStr, mdstr].join("\n")
        array=[Filex.expandStr(dx, auxhs, @mes, {"mdfname" => mdfname})]
      when :YAML_TO_MD
        objy=checkAndExpandYamlfile(datayamlfname, objx)
        erubystr=checkAndLoadErubyfile(templatefile)
        dx = [@erubyStaticStr, erubystr].join("\n")

        array=[Filex.expandStr(dx, objy, @mes, {"datayamlfname" => datayamlfname , "templatefile" => templatefile})]
      else
        raise
#        array=[]
      end
      array
    end

    def load(dataop, datayamlfname, yamlop, auxyamlfname, yamlfname, erubyfnames, auxhs)
      eruby0 = nil
      eruby1 = nil
      obj = {}
      if auxyamlfname
        unless @yamlfiles[auxyamlfname]
          @yamlfiles[auxyamlfname]=YAML.load_file(auxyamlfname)
        end
        obj0=@yamlfiles[auxyamlfname].dup
      end

      obj = obj0 if obj0

      case yamlop
      when :MERGE
        unless @yamlfiles[yamlfname]
          @yamlfiles[yamlfname]=YAML.load_file(yamlfname)
        end
        obj2 = @yamlfiles[yamlfname].dup
        if obj2
          if obj
            objx = obj.merge(obj2)
          else
            objx = obj2
          end
        else
          objx = obj
        end
      when :REPLACE
        str=File.read(yamlfname)
        str2=Filex.expandStr(str, obj, @mes, {"mdfname"=>mdfname, "erubyfnames"=>erubyfnames})

        unless @yamlfiles[yamlfname]
          @yamlfiles[yamlfname]=YAML.load(str2)
        end
        objx0=@yamlfiles[yamlfname].dup
        if objx0
          objx = objx
        else
          objx = {}
        end
      else
        # do nothing
      end

      erubystr=erubyfnames.map{|x| checkAndLoadErubyfile(x)}.join("\n")
      if @dataop == :PATTERN_FOUR
        mdfname=datayamlfname
        objx["parentDir"] = ENV['MDEXTAB_MAKE']

        mdstr=checkAndLoadMdfile(mdfname)

        dx = [erubystr, mdstr].join("\n")
        unless @erubies[mdfname]
          @erubies[mdfname]=Erubis::Eruby.new(dx)
        end
        array=[Filex.expandStr(dx, objx, @mes, {"mdfname"=>mdfname})]
      else
        objx.merge!(auxhs)
          strdata2=checkAndExpandYamlfile(datayamlfname, objx)
          unless @yamlfiles[datayamlfname]
            @yamlfiles[datayamlfname]=YAML.load(strdata2)
          end
          data=@yamlfiles[datayamlfname].dup
          if data.class != Hash
            @mes.outputFatal(data)
            exit(@mes.exitCode["EXIT_CODE_DATA_CLASS_ISNOT_HASH"])
          end
          erubyfname=erubyfnames.last
          case dataop
          when :PATTERN_ONE
            array=loadWithPattern1(data, erubystr)
          else
            array=[]
            # do nothing
          end
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
        str=Filex.checkAndExpandFile(yamlfname, objx, @mes)
        @str_yamlfiles[yamlfname]=YAML.load(str)
      end
      @str_yamlfiles[yamlfname]
    end

    def checkAndLoadMdfile(mdfname)
      unless @str_mdfiles[mdfname]
        @str_mdfiles[mdfname]=Filex.checkAndLoadFile(mdfname, @mes)
      end
      @str_mdfiles[mdfname]
    end

    def loadWithPattern1(data, erubystr)
      [Filex.expandStr(erubystr, data, @mes)]
    end

    def postProcess
      @output.close if @output
      @output = nil
    end
  end
end
