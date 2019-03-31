require 'yaml'
require 'erubis'

module Mdextab
  module Yamlx
    extend self

    def loadSetting(yamlfname , auxiliaryYamlFname, erubyfname , hs={})
      if yamlfname
        begin
          obj = YAML.load_file(yamlfname)
        rescue RuntimeError => ex
          obj = {}
        end
        obj = {} unless obj
      else
        obj = {}
      end

      if auxiliaryYamlFname
        begin
          obj2 = YAML.load_file(auxiliaryYamlFname)
        rescue RuntimeError => ex
          obj2 = {}
        end
        obj2 = {} unless obj2
      else
        obj2 = {}
      end
      obj3 = obj.merge(obj2)

      str = File.read(erubyfname)
      Erubis::Eruby.new(str).result(obj3).split("\n")
#      File.readlines( erubyfname ).map{|x| Erubis::Eruby.new(x).result(obj3)}
    end

    def getContent( fname , hash = {} )
      if File.exist?( fname )
        fpath = fname
      else
        fpath = File.join( Dir.pwd , fname )
      end
      str = File.read( fpath )
      eruby = Erubis::Eruby.new( str )
      eruby.result( hash )
    end

    def changeContext( obj )
      obj_new = {}
      obj.each{|k,v|
        if v.class == Hash
          if v["path"]
            hs = {}
            v.each{|k2,v2|
              hs[k2]=v2 if k2 != "path"
            }
            obj_new[k] = get_content( v["path"] , hs )
          end
        end
      }
      obj_new.each{|k3,v3|
        obj[k3] = v3
      }
      obj_new
    end
  end
end
