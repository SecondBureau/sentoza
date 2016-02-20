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

      
      APPS_PATH = 'apps'
      SHARED_PATH = '../shared' # relative to rails application root
      
      attr_accessor :settings
      
      def initialize
        @settings ||= load_settings
      end
      
      def install(arguments)
        do_install(:charbon, :staging)
      end
      
      private
      
      def do_install(application, stage)
        
        github_repository = settings.github(application)[:repository]
        
        path = File.join(APP_ROOT, APPS_PATH, application.to_s, 'src')
        
         Rugged::Repository.clone_at("https://github.com/#{github_repository}", path, {
           transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
            print "#{received_objects} / #{total_objects} objects \r"
           }
         })
        
        stage_path = File.join(APP_ROOT, APPS_PATH, application.to_s, stage.to_s)
        FileUtils.mkdir_p stage_path
        
        repo = Rugged::Repository.new(path)
        
        # checkout branch
        branch = settings.stage(application, stage)[:branch]
        repo.checkout(branch)
        oid = repo.rev_parse_oid('HEAD')
        revision = oid[0,7]
        
        # copy
        app_root = File.join(APP_ROOT, APPS_PATH, application.to_s, stage.to_s, revision)
        FileUtils.rm_rf app_root
        FileUtils.cp_r path, app_root 
        FileUtils.rm_r("#{app_root}/.git", :force => true)
        
        # config
        shared_dir = File.join(app_root, SHARED_PATH)
        FileUtils.mkdir_p shared_dir
        shared_dir = File.realpath shared_dir
        
        # database.yml
        appl_db_config_path   = File.join(app_root, 'config', 'database.yml')
        shared_db_config_path = File.join(shared_dir, 'database.yml')
        
        File.open(shared_db_config_path,"w") do |file|
          file.write DATABASE_TPL
        end
        
        FileUtils.ln_sf shared_db_config_path, appl_db_config_path
        
        
        #puma.rb
        appl_puma_path   = File.join(app_root, 'config', 'puma.rb')
        shared_puma_path = File.join(shared_dir, 'puma.rb')
        
        File.open(shared_puma_path,"w") do |file|
          file.write PUMA_TPL.gsub!('{{shared_dir}}', shared_dir)
        end
        
        FileUtils.ln_sf shared_puma_path, appl_puma_path
        
        # activate
        FileUtils.ln_sf  app_root, File.join(APP_ROOT, APPS_PATH, application.to_s, stage.to_s, 'current')
        
      end
      
    end
  end
end