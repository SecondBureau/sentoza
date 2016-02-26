require_relative 'base'

module Sentoza
  module Generator
    class NGinx < Sentoza::Generator::Base
      
      SITES_AVAILABLE = "/etc/nginx/sites-available"
      SITES_ENABLED   = "/etc/nginx/sites-enabled"
      
      TEMPLATE = <<-EOT
upstream {{APPLICATION}}_{{STAGE}} {
  # Path to Puma SOCK file, as defined in app/config/puma.rb
  server unix:{{APP_ROOT}}/apps/{{APPLICATION}}/{{STAGE}}/shared/sockets/puma.sock fail_timeout=0;
}

server {
  listen 80;
  server_name {{VHOST}};

  root {{APP_ROOT}}/apps/{{APPLICATION}}/{{STAGE}}/current/public;
  access_log {{APP_ROOT}}/apps/{{APPLICATION}}/{{STAGE}}/shared/log/nginx.access.log;
  error_log {{APP_ROOT}}/apps/{{APPLICATION}}/{{STAGE}}/shared/log/nginx.error.log info;
  
  location ~ ^/assets/ {
    expires 1y;
    add_header Cache-Control public;
    add_header ETag "";
    break;
  }

  try_files $uri/index.html $uri @{{APPLICATION}}_{{STAGE}};

  location @{{APPLICATION}}_{{STAGE}} {
      proxy_pass http://{{APPLICATION}}_{{STAGE}};
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header Host $http_host;
      proxy_redirect off;
  }
  


  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}

EOT
      
      class << self
              
        private
      
        def parse_arguments(arguments)
          options = {}
          OptionParser.new do |opts|
            opts.banner = "Usage: sentoza generate nginx [options]"
            opts.separator ""
            opts.on("-a", "--application=NAME", String,
                    "Name of the application.", "Default: all") { |v| options[:application] = v }
            opts.on("-s", "--stage=STAGE", String,
                    "Stages for this application.", "Default: all") do |v| 
                      options[:stages] ||= []
                      options[:stages] << v.to_sym
                    end
            opts.separator ""
            opts.on("-s", "--simulate", TrueClass,
                    "Does not install files in /etc/nginx/sites-available/", "Default: false") { |v| options[:simulate] = v }
            opts.on("-i", "--install", TrueClass,
                    "Only install files in /etc/nginx/sites-available/", "Default: false") { |v| options[:install_only] = v }
            
            opts.on("-e", "--enable", 
                    "enable vhost", "Default: active param") { |v| options[:enable] = v }
            opts.separator ""
         
            opts.on_tail("-h", "--help", "Shows this help message.") { puts opts; exit }
          
            opts.parse!(arguments)
          end
          options
        end
        
      end
      
      def run!(options)
        init_repo unless check_repo
        mk_config_file unless options[:install_only]
        unless options[:simulate]
          install_file
          if options[:enable] || stage.active
            enable
          else
            disable
          end
          restart
        end
      end
      
      def check_repo
        if File.exist?(SITES_AVAILABLE) && File.exist?(SITES_ENABLED)
          log.info ["Checked repositories '#{SITES_AVAILABLE}', '#{SITES_ENABLED}'", :done]
          return true
        else
          log.warning "Repositories '#{SITES_AVAILABLE}', '#{SITES_ENABLED}' must be created"
          return false
        end
      end
    
      def init_repo
        log.info "Creating repositories '#{SITES_AVAILABLE}', '#{SITES_ENABLED}'", true
        begin
          FileUtils.mkdir_p SITES_AVAILABLE
          FileUtils.mkdir_p SITES_ENABLED
          log.result :done
        rescue Errno::EACCES
          log.result :failed
          log.error "Permission Denied to create '#{SITES_AVAILABLE}', '#{SITES_ENABLED}'.\n   Run this command with sudo"
        end
      end
      
      def mk_config_file

        params = {
          app_root:  APP_ROOT,
          vhost: stage.vhost,
          application: application.name.to_s,
          stage: stage.name.to_s
        }

        contents = TEMPLATE
        %w(app_root application stage vhost).each do |param| 
          contents.gsub! "{{#{param.upcase}}}", params[param.to_sym].to_s
        end
        
        File.open(config_path,"w") do |file|
          file.write contents
        end
        
      end
      
      def install_file
        log.info "install files", true
        begin
          FileUtils.cp config_path, nginx_path
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      def enable
        log.info "enable appplication", true
        begin
          ln nginx_path, File.join(SITES_ENABLED, filename)
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      def disable
        log.info "Disable application", true
        begin
          FileUtils.rm File.join(SITES_ENABLED, filename)
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      def restart
        log.info "Restart NGinx", true
        begin
          `service nginx restart`
          log.result :done
        rescue Exception => e
          log.result :failed
          log.error e.message
        end
      end
      
      
      def filename
        "nginx_#{application.name.to_s}_#{stage.name.to_s}"
      end
      
      def config_path
        File.join config_dir, filename
      end
      
      def nginx_path
        File.join SITES_AVAILABLE, filename
      end
      
      
      
    end
  end
end