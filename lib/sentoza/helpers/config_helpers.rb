

module Sentoza
  module ConfigHelpers
    
    CONFIG_DIR = 'config'
    
    def self.included(base)
      base.extend(ClassMethods)
    end
      
    module ClassMethods
     
    end
    
    def config_dir
      File.join APP_ROOT, CONFIG_DIR
    end
    
  end
  
end