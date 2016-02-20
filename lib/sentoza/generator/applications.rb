require_relative 'base'

module Sentoza
  module Generator
    class Applications < Sentoza::Generator::Base
      
      DATABASE_TPL = <<-EOT      
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5
  database: <%= ENV['DB_NAME'] %>
  username: <%= ENV['DB_USERNAME'] %>
  password: <%= ENV['DB_PASSWORD'] %>
  host: <%= ENV['DB_HOSTNAME'] %>
  port: <%= ENV['DB_PORT'] %>

development:
  <<: *default

stagging:
  <<: *default

test:
  <<: *default

production:
  <<: *default
      
EOT

      PUMA_TPL = <<-EOT

workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 5)
threads threads_count, threads_count

# Default to production
rails_env = ENV['RAILS_ENV'] || "production"
environment rails_env

# Set up socket location
bind "unix://{{shared_dir}}/sockets/puma.sock"

# Logging
stdout_redirect "{{shared_dir}}/log/puma.stdout.log", "{{shared_dir}}/log/puma.stderr.log", true

# Set master PID and state locations
pidfile "{{shared_dir}}/pids/puma.pid"
state_path "{{shared_dir}}/pids/puma.state"
activate_control_app

on_worker_boot do
  require "active_record"
  ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
  ActiveRecord::Base.establish_connection(YAML.load_file("{{shared_dir}}/database.yml")[rails_env])
end

EOT

      BUNDLE_TPL = <<-EOT
---
BUNDLE_PATH: "../shared/bundle"
BUNDLE_DISABLED_SHARED_GEMS: '1'
BUNDLE_WITHOUT: heroku

EOT

      
      APPS_PATH = 'apps'
      SHARED_PATH = '../shared' # relative to rails application root
            
      attr_accessor :repo, :app_root, :shared_dir
      attr_accessor :appl_db_config_path, :shared_db_config_path
      attr_accessor :appl_puma_path, :shared_puma_path
      attr_accessor :appl_bundle_path, :shared_bundle_path
      
      def install(arguments)
        options = parse_arguments(arguments)
        applications(options).each do |application|
          stages(options, application).each do |stage| 
            self.class.new(application, stage).do_install
          end
        end
      end
      
      def do_install
        exit_if_application_or_stage_doesnt_exist
        clone
        copy_tree
        init_shared_dir
        mk_database_config
        mk_puma_config
        mk_bundle_config
        update_links
      end
      
private
            
      def clone
        path = File.join(APP_ROOT, APPS_PATH, application.to_s, 'src')
        unless File.exist? path
          github_repository = settings.github(application)[:repository]
          Rugged::Repository.clone_at("https://github.com/#{github_repository}", path, {
            transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
            print "#{received_objects} / #{total_objects} objects \r"
            }
          })
        end
        @repo = Rugged::Repository.new(path)
      end
      
      def copy_tree
        # make stage dir
        stage_path = File.join(APP_ROOT, APPS_PATH, application.to_s, stage.to_s)
        FileUtils.mkdir_p stage_path

        # checkout branch
        branch = settings.stage(application, stage)[:branch]
        repo.checkout(branch)
        oid = repo.rev_parse_oid('HEAD')
        revision = oid[0,7]
        
        # copy
        repo_root = File.dirname(@repo.path)
        @app_root = File.join(stage_path, revision)
        FileUtils.rm_rf app_root
        FileUtils.cp_r repo_root, app_root 
        FileUtils.rm_r("#{app_root}/.git", :force => true)
      end
      
      def init_shared_dir
        shared_dir = File.join(app_root, SHARED_PATH)
        FileUtils.mkdir_p shared_dir
        @shared_dir = File.expand_path shared_dir
      end
      
      def mk_database_config
        filename = 'database.yml'
        @appl_db_config_path   = File.join(app_root, 'config', filename)
        @shared_db_config_path = File.join(shared_dir, filename)
        File.open(shared_db_config_path,"w") do |file|
          file.write DATABASE_TPL
        end
      end
      
      def mk_puma_config
        filename = 'puma.rb'
        @appl_puma_path   = File.join(app_root, 'config', filename)
        @shared_puma_path = File.join(shared_dir, filename)
        File.open(shared_puma_path,"w") do |file|
          file.write PUMA_TPL.gsub!('{{shared_dir}}', shared_dir)
        end
      end
      
      def mk_bundle_config
        @appl_bundle_path   = File.join(app_root, '.bundle', 'config')
        @shared_bundle_path = File.join(shared_dir, "bundle.config")
        FileUtils.mkdir_p appl_bundle_path
        File.open(shared_bundle_path,"w") do |file|
          file.write BUNDLE_TPL
        end
      end
      
      def update_links
        ln shared_db_config_path, appl_db_config_path
        ln shared_puma_path, appl_puma_path
        ln shared_bundle_path, appl_bundle_path
        ln app_root, File.join(APP_ROOT, APPS_PATH, application.to_s, stage.to_s, 'current')
      end
      
      def ln(target, source)
        FileUtils.rm_f source
        FileUtils.ln_sf Pathname.new(target).relative_path_from(Pathname.new(File.dirname(source))).to_s, source
      end
      
      def parse_arguments(arguments)
        options = {}
        OptionParser.new do |opts|
          opts.banner = "Usage: sentoza generate applications [options]"
          opts.separator ""
          opts.on("-a", "--application=NAME", String,
                  "Name of the application.", "Default: all") { |v| options[:application] = v }
          opts.on("-s", "--stage=STAGE", String,
                  "Stages for this application.", "Default: all") do |v| 
                    options[:stages] ||= []
                    options[:stages] << v.to_sym
                  end
          opts.separator ""
         
          opts.on_tail("-h", "--help", "Shows this help message.") { puts opts; exit }
          
          opts.parse!(arguments)
        end
        options
      end
      
    end
  end
end