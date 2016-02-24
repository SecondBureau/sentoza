require_relative 'base'
require 'securerandom'
require_relative '../helpers/application_helpers'


module Sentoza
  module Generator
    
    class RepoExists < ::StandardError; end
  
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
      
      
      PUMA_CONF_PATH  = '/etc/puma.conf'
      
      class << self
        
        private
        
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
            
            opts.on("-f", "--fetch", TrueClass,
                    "Will fetch the latest if repo exists.") { |v| options[:fetch] = v }
         
            opts.on_tail("-h", "--help", "Shows this help message.") { puts opts; exit }
          
            opts.parse!(arguments)
          end
          options
        end
        
      end
      
      
      def initialize(application=nil, stage=nil)
        super
        @restart = false
      end
      
      def run!(options)
        begin
          clone
        rescue RepoExists
          if options[:fetch]
            fetch
          else
            log.warning ["'#{application.github.repository}' already exists in '#{clone_path}'", :skipped]
          end
        end
        FileUtils.mkdir_p stage_path
        checkout
        copy_tree
        init_shared_dir
        mk_database_config
        mk_puma_config
        mk_bundle_config
        mk_rbenv_vars
        add_puma_conf
        update_links
        restart_puma_manager
      end
      
private
            
      def clone
        github_repository = application.github.repository
        log.info "Cloning '#{github_repository}'..."
        unless File.exist? clone_path
          Rugged::Repository.clone_at("https://github.com/#{github_repository}", clone_path, {
            transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
            print "#{received_objects} / #{total_objects} objects \r"
            }
          })
          log.info ["'#{github_repository}' cloned", :done]
        else
          raise RepoExists
        end
      end
      
      def init_shared_dir
        log.info "Create shared directory", true
        begin
          FileUtils.mkdir_p File.join(app_root, SHARED_PATH)
          FileUtils.mkdir_p File.join(app_root, SHARED_PATH, 'log')
          FileUtils.mkdir_p File.join(app_root, SHARED_PATH, 'pids')
          FileUtils.mkdir_p File.join(app_root, SHARED_PATH, 'sockets')
          FileUtils.mkdir_p File.join(app_root, SHARED_PATH, 'assets')
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      def mk_database_config
        log.info "Make database config", true
        begin
          File.open(shared_db_config_path,"w") do |file|
            file.write DATABASE_TPL
          end
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      def mk_puma_config
        log.info "Make puma config", true
        begin
          File.open(shared_puma_path,"w") do |file|
            file.write PUMA_TPL.gsub!('{{shared_dir}}', shared_dir)
          end
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      def mk_bundle_config
        log.info "Make bundle config", true
        begin
          File.open(shared_bundle_path,"w") do |file|
            file.write BUNDLE_TPL
          end
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      def mk_rbenv_vars
        log.info "Make rbenv vars ", true
        begin
          File.open(shared_rbenv_vars_path,"w") do |file|
            file.puts "DB_NAME=#{stage.db[:name]}"
            file.puts "DB_USERNAME=#{stage.db[:username]}"
            file.puts "DB_PASSWORD=#{stage.db[:password]}"
            file.puts "DB_HOSTNAME=#{stage.db[:hostname]}"
            file.puts "DB_PORT=#{stage.db[:port]}"
            file.puts "SECRET_KEY_BASE=#{SecureRandom.hex(64)}"
            file.puts "RAILS_ENV=production"
            file.puts "RAILS_SERVE_STATIC_FILES=true"
          end
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      def add_puma_conf
        log.info "Checking Puma Manager configuration", true
        begin
          if !File.exist?(PUMA_CONF_PATH)
            log.result :failed
            log.error "Puma manager application list '#{PUMA_CONF_PATH}' is missing."
            return
          end
          found = false 
          File.read(PUMA_CONF_PATH).each_line do |line|
            if line.chop!.eql?(current_root)
              found = true
              break
            end
          end
          unless found
            begin
              File.open(PUMA_CONF_PATH,"a") do |file|
                file.puts current_root
              end
              @restart = true
            rescue Errno::EACCES
              raise "Permission denied to modify '#{PUMA_CONF_PATH}'.\n        Try to run this command with sudo.\n        Or add #{current_root} to this file.\n        And restart puma manager 'sudo restart puma-manager'"
            end
          end
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      
      
    end
  end
end