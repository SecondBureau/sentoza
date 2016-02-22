require_relative 'base'
require_relative '../settings'

module Sentoza
  module Generator
    class Settings < Sentoza::Generator::Base
      
      include ConfigHelpers
      
      DEFAULT_GITHUB_REMOTE = 'origin'
      DEFAULT_STAGE_BRANCH  = 'master'
      DEFAULT_STAGE_VHOST   = 'example.org'
      DEFAULT_DB_PORT       = 5432
      DEFAULT_APPLICATION_NAME = 'myapp'
      DEFAULT_STAGES = %w(production staging)
      
      class << self
      
        def generate(arguments)
          options = parse_arguments(arguments)
          self.new.run!(options)
        end
      
        private
      
        def parse_arguments(arguments)
          options = {
            stage: {},
            github: {},
            db: {}
          }
          OptionParser.new do |opts|
            opts.banner = "Usage: sentoza generate config [options]"
            opts.separator ""
            opts.on("-a", "--application=NAME", String,
                    "Name of the application.", "Default: myapp") { |v| options[:application] = v }
            opts.on("-s", "--stage=STAGE", String,
                    "Stages for this application.", "Default: production staging") do |v| 
                      options[:stages] ||= []
                      options[:stages] << v.to_sym
                    end
            opts.on("--replace", 
                    "Replace current file.", "Default: False") { |v| options[:replace] = v }

            opts.separator ""
          
            opts.on("-R", "--repository=REPOSITORY", String,
                    "Github repository of the application.", "Default: ") { |v| options[:github][:repository] = v }
            opts.on("-r", "--remote=REMOTE", String,
                    "Git remote of the application.", "Default: origin") { |v| options[:github][:remote] = v }
            opts.on("-b", "--branch=BRANCH", String,
                    "Github Branch.", "Default: none") { |v| options[:stage][:branch] = v }
            opts.on("-v", "--vhost=VHOST", String,
                    "Virtual host.", "Default: stage.example.org") { |v| options[:stage][:vhost] = v }
            opts.on("--[no-]active", TrueClass,
                    "Activate this stage.", "Default: Active") { |v| options[:stage][:active] = v }
          
            opts.separator ""
          
            opts.on("-n", "--name=NAME", String,
                    "PostgreSQL DB Name.", "Default: none") { |v| options[:db][:name] = v }          
 
                    opts.on("-u", "--username=NAME[:PASSWORD]", String,
                            "PostgreSQL Credentials.", "Default: none") do |v| 
                              credentials = v.split(':')
                              options[:db][:username] = credentials[0]
                              options[:db][:password] = credentials[1] if credentials.size > 1
                            end   
                          
            opts.on("--password=PASSWORD", String,
                    "PostgreSQL password.", "Default: none") { |v| options[:db][:password] = v }     
            opts.on("-H", "--host=HOST[:PORT]", String,
                    "PostgreSQL host.", "Default: port 5432") do |v| 
                      params = v.split(':')
                      options[:db][:hostname] = params[0]
                      options[:db][:port] = params[1] if params.size > 1
                    end
            opts.on("--port=PORT", Integer,
                    "PostgreSQL port", "Default: 5432") { |v| options[:db][:port] = v }                
          
           opts.separator ""
         
            opts.on_tail("-h", "--help", "Shows this help message.") { puts opts; exit }
          
            opts.parse!(arguments)
          end
          options
        end
      end
      
      def initialize
      end
      
      def run!(options)
        
        mk_config_dir
        
        settings_path = Sentoza::Settings::Base.path
        settings = Sentoza::Settings::Base.new(File.exist?(settings_path) && !options[:replace])

        app = settings.find_or_create (options[:application] || DEFAULT_APPLICATION_NAME).to_sym
        app.github.set github(options[:github])
        
        stages = options[:stages] || DEFAULT_STAGES
        options[:stage][:db] = options[:db]
        
        stages.each do |stage|
          s = app.find_or_create stage.to_sym
          s.set stage(stage, options[:stage])
        end
        
        File.open(settings_path,"w") do |file|
          file.write settings.to_yaml
        end
        
      end
      
      private
      
      def github(options={})
        {
          repository: option(options, :repository),
          remote: option(options, :remote, DEFAULT_GITHUB_REMOTE)
        }
      end
      
      def stage(stage, options={})
        options_db = options[:db] if options
        {
          branch: option(options, :branch, DEFAULT_STAGE_BRANCH),
          vhost: option(options, :vhost, "#{stage}.#{DEFAULT_STAGE_VHOST}"),
          active: option(options, :active, true),
          db: db(options_db)
        }
      end
      
      def db(options={})
        %w(name username password hostname port).inject({}) do |result, element|
          result[element.to_sym] = option(options, element.to_sym, default("DB_#{element.upcase}"))
          result
        end
      end
      
      def mk_config_dir
        return if File.exist?(config_dir)
        begin
          FileUtils.mkdir_p config_dir
        rescue Errno::EACCES
          log.error "Permission Denied to create '#{dir}'"
          exit 1
        end
      end
      
    end
  end
end