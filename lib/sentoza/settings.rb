module Sentoza
  
  class Settings
    
    PATH = File.join(APP_ROOT, 'config', 'sentoza.yml')
    
    attr_accessor :params
  
    def initialize
      load
    end
    
    def applications
      @applications ||= @params.keys
    end
    
    def github(application)
      @params[application.to_sym][:github]
    end
    
    def stages(application)
      return [] unless @params[application.to_sym]
      @params[application.to_sym].reject{|i| i.eql?(:github)}.keys
    end
    
    def stage(application, stage)
      @params[application.to_sym][stage.to_sym]
    end
    
    def db(application, stage)
      @params[application.to_sym][stage.to_sym][:db]
    end
    
    private
    
    def load
      if File.exist?(PATH)
        @params = YAML.load(File.open(PATH))
      else
        puts "Config file does not exist. Please generate it with 'sentoza g config'"
        exit 1
      end
    end
  
  end
end