require_relative 'helpers/config_helpers'
require_relative 'helpers/util_helpers'

module Sentoza
  module Settings
    class Application
      attr_accessor :name, :github, :stages
      def initialize(name)
        @name = name
        @github = Github.new
        @stages = {}
      end
      def find_by_branch(branch)
        stage = stages.find {|k, s| s.branch.eql?(branch)}
        raise(StageNotFound, "Stage '#{stage}' can not be found.") if stage.nil?
        stage[1]
      end
      def find(stage)
        raise(StageNotFound, "Stage '#{stage}' can not be found.") unless stages.has_key?(stage.to_sym)
        stages[stage.to_sym]
      end
      def find_or_create(stage)
        stages[stage] ||= Stage.new(stage)
      end
    end
  end
end

module Sentoza
  module Settings
    class Github
      attr_accessor :repository, :remote
      def initialize(params=nil)
        set params unless params.nil?
      end
      def set(params={})
        @repository = params[:repository]
        @remote     = params[:remote]
      end
      def to_hash
        {
          repository: repository,
          remote:     remote
        }
      end
    end
  end
end

module Sentoza
  module Settings
    class Stage
      attr_accessor :name, :branch, :vhost, :active, :db
      def initialize(name, params=nil)
        @name = name
        @db = {}
        set params unless params.nil?
      end
      def set(params={})
        @branch = params[:branch]
        @vhost  = params[:vhost]
        @active = params[:active]
        @db     = params[:db]
      end
      def to_hash
        {
          branch: branch,
          vhost:  vhost,
          active: active,
          db:     db  
        }
      end
    end
  end
end


module Sentoza
  
  module Settings
    
    class ApplicationNotFound < ::StandardError; end
    
    class StageNotFound < ::StandardError; end
    
    class Base
    
      attr_accessor :applications
    
      FILENAME = 'sentoza.yml'
    
      include ConfigHelpers 
      include UtilHelpers 
    
      class << self
      
        def path
          File.join APP_ROOT, Sentoza::ConfigHelpers::CONFIG_DIR, FILENAME
        end
        
        def applications(options)
          options[:application] ? [options[:application]] : Settings::Base.new.applications.keys
        end
    
        def stages(options, application)
          options[:stages] ? options[:stages] : Settings::Base.new.find(application).stages.keys
        end
    
      end
  
      def initialize(load=true)
        if load
          load! 
        else
          @applications = {}
        end
      end
      
      def find(application)
        raise(ApplicationNotFound, "Application '#{application}' can not be found.") unless applications.has_key?(application.to_sym)
        @applications[application.to_sym]
      end
    
      def find_or_create(application)
        @applications[application] ||= Application.new(application)
      end
    
      def to_yaml
        tree.to_yaml[3...-1]
      end
    
      # def applications
      #   @applications ||= @params.keys
      # end
      #
      # def github(application)
      #   @params[application.to_sym][:github]
      # end
      #
      # def stages(application)
      #   return [] unless @params[application.to_sym]
      #   @params[application.to_sym].reject{|i| i.eql?(:github)}.keys
      # end
      #
      # def stage(application, stage)
      #   @params[application.to_sym][stage.to_sym]
      # end
      #
      # def db(application, stage)
      #   @params[application.to_sym][stage.to_sym][:db]
      # end
      #   
      private
    
      def tree
        applications.values.inject({}) do |result, element|
          result[element.name] = { github: element.github.to_hash }
          element.stages.values.each do |stage|
            result[element.name][stage.name] = stage.to_hash
          end
          result
        end
      end
    
      def load!
        if File.exist?(self.class.path)
          parse YAML.load(File.open(self.class.path))
        else
          log.error "Config file does not exist. Please generate it with 'sentoza g config'"
          exit 1
        end
      end
    
      def parse(settings)
        @applications = {}
        settings.each do |application, params|
          app = Application.new(application)
          app.github = Github.new(params[:github])
          params.reject{|i| i.eql?(:github)}.keys.each do |stage|
            app.stages[stage] = Stage.new(stage, params[stage])
          end
          @applications[application] = app
        end
      end
      
    end 
  end
end

