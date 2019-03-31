require 'logger'

module Mdextab
  class Loggerx
    def initialize(fname)
      @loggerSTDOUT = Logger.new(STDOUT)
      @loggerSTDOUT.level = Logger::UNKNOWN
      @loggerSTDOUT.formatter = proc do |severity, datetime, progname, msg|
        "#{severity[0]}: #{msg}\n"
#        "#{msg}\n"
      end    
      file = File.open( fname , 'w')
      @loggerFILE = Logger.new(file)
      @loggerFILE.level = Logger::INFO
      @loggerFILE.formatter = proc do |severity, datetime, progname, msg|
        "#{severity}: #{msg}\n"
#       "#{msg}\n"
      end    
    end

    def datetime_format=(format)
      @loggerSTDOUT.datetime_format=format
      @loggerFILE.datetime_format=format
    end

    def level=(value)
      puts value
      @loggerSTDOUT.level=value
      @loggerFILE.level=value
    end

    def set_level(value)
      puts value
      @loggerSTDOUT.level=value
      @loggerFILE.level=value
    end

    def debug(mes)
      @loggerSTDOUT.debug(mes)
      @loggerFILE.debug(mes)
    end

    def error(mes)
      @loggerSTDOUT.error(mes)
      @loggerFILE.error(mes)
    end

    def fatal(mes)
      @loggerSTDOUT.fatal(mes)
      @loggerFILE.fatal(mes)
    end

    def info(mes)
      @loggerSTDOUT.info(mes)
      @loggerFILE.info(mes)
    end
  end
end
