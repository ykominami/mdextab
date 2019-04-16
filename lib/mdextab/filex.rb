module Mdextab
  require 'digest'
  require 'pp'
  require 'erubis'

  class Filex
    def self.setup(mes)
      mes.addExitCode("EXIT_CODE_CANNOT_FIND_FILE_OR_EMPTY")
      mes.addExitCode("EXIT_CODE_FILE_IS_EMPTY")
      mes.addExitCode("EXIT_CODE_NAME_ERROR_EXCEPTION_IN_ERUBY")
      mes.addExitCode("EXIT_CODE_ERROR_EXCEPTION_IN_ERUBY")
    end

    def self.checkAndExpandFileLines(fname, data, mes)
       checkAndExpandFile(fname, data, mes).split("\n")
    end

    def self.checkAndLoadFile(fname, mes)
      size=File.size?(fname)
      if size and size > 0
        strdata=File.read(fname)
      else
        mesg=%Q!Can not find #{fname} or is empty!
        mes.outputError(mesg)
        exit(mes.exitCode["EXIT_CODE_CANNOT_FIND_FILE_OR_EMPTY"])
      end

      if strdata.strip.empty?
        mesg=%Q!#{fname} is empty!
        mes.outputError(mesg)
        exit(mes.exitCode["EXIT_CODE_FILE_IS_EMPTY"])
      else
        mes.outputInfo(Digest::MD5.hexdigest(strdata))
      end

      strdata
    end

    def self.expandStr(erubyStr, data, mes,fnames={})
      begin
        strdata=Erubis::Eruby.new(erubyStr).result(data)
      rescue NameError => ex
        puts "ex.class=#{ex.class}"
        mes.outputFatal(ex.class)
        puts "ex.message=#{ex.message}"
        mes.outputFatal(ex.message)
        pp ex.backtrace
        mes.outputFatal(ex.backtrace.join("\n"))
        fnames.map{|x| mes.outputFatal( %Q!#{x[0]}=#{x[1]}! )}
        exit(mes.exitCode["EXIT_CODE_NAME_ERROR_EXCEPTION_IN_ERUBY"])
      rescue Error => ex
        mes.outputFatal(ex.class)
        mes.outputFatal(ex.message)
        mes.outputFatal(ex.backtrace.join("\n"))
        fnames.map{|x| mes.outputFatal(%Q!#{x[0]}=#{x[1]}!) }
        exit(mes.exitCode["EXIT_CODE_ERROR_EXCEPTION_IN_ERUBY"])
      end
      strdata
    end

    def self.checkAndExpandFile(fname, objx, mes)
      strdata=checkAndLoadFile(fname, mes)
      strdata2=expandStr(strdata, objx, mes, {fname: fname})
      strdata2
    end

    def self.escapeBySingleQuoteInYamlFileToStr(fname)
      self.escapeBySingleQuoteInYamlFileToLines(fname).join("\n")  
    end

    def self.escapeBySingleQuoteInYamlFileToLines(fname)
      File.readlines.map{|x|
        x.chomp!
        self.escapeBySingleQuoteInYamlFormatOneLine(x)
      }
    end

    def self.escapeBySingleQuoteInYamlFormat(str)
      str.split("\n").map{|x|
        self.escapeBySingleQuoteInYamlFormatOneLine(x)
      }.join("\n")
    end

    def self.escapeBySingleQuoteInYamlFormatOneLine(x, prevQuotoFlag=false)
      if (m=/(^[\s\-]+)([^\-\s].*)/.match(x))
        l=m[1]
        r=m[2]
        if prevQuotoFlag
#            puts "===A-1"
          l+" '"+r+"'"
        else
          index=r.index('-')
          index=r.index('*') unless index
          index=r.index(':') unless index
          if index
#            puts "===A0"
            l+" '"+r+"'"
          else
#            puts "===A1"
            l+r
          end
        end
      elsif (index=x.index(':'))
        if index
          l=x.slice(0,(index+1))
          r=x.slice((index+1),x.size)
        else
          l=x
          r=nil
        end
        #      l,r=x.split(':')
        if r and !(r.strip.empty?)
#          puts "===2"
          l+" '"+r+"'"
        else
#          puts "===3"
          l
        end
      else
#       puts "===4"
        x
      end
    end

    def self.escapeBySingleQuoteInYamlFormatOneLine_0(x)
      index=x.index(':')
      if index
        l=x.slice(0,(index+1))
        r=x.slice((index+1),x.size)
      else
        l=x
        r=nil
      end
#      l,r=x.split(':')
      if r and !(r.strip.empty?)
        l+"'"+r+"'"
      else
        l
      end
    end
  end
end
