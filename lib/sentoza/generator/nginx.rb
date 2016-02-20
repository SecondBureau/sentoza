# upstream app {
#     # Path to Puma SOCK file, as defined in app/config/puma.rb
#     server unix:/home/deploy/charbon/shared/sockets/puma.sock fail_timeout=0;
# }
#
# server {
#     listen 80;
#     server_name localhost;
#
#     root /home/deploy/charbon;
#
#     try_files $uri/index.html $uri @app;
#
#     location @app {
#         proxy_pass http://app;
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         proxy_set_header Host $http_host;
#         proxy_redirect off;
#     }
#
#     error_page 500 502 503 504 /500.html;
#     client_max_body_size 4G;
#     keepalive_timeout 10;
# }



require_relative 'base'
require_relative '../settings'

module Sentoza
  module Generator
    class NGinx < Sentoza::Generator::Base
      
      SITES_AVAILABLE = "/etc/nginx/sites-available"
      SITES_ENABLED   = "/etc/nginx/sites-enabled"
      
      TEMPLATE = <<-EOT
upstream app {
  # Path to Puma SOCK file, as defined in app/config/puma.rb
  server unix: {{APP_ROOT}}/apps/{{APPLICATION}}/{{STAGE}}/shared/sockets/puma.sock fail_timeout=0;
}

server {
  listen 80;
  server_name {{VHOST}};

  root {{APP_ROOT}}/apps/{{APPLICATION}}/{{STAGE}}/current;

  try_files $uri/index.html $uri @app;

  location @app {
      proxy_pass http://app;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header Host $http_host;
      proxy_redirect off;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}

EOT
      
      
      def generate(arguments)
        init_repo
        options = parse_arguments(arguments)
        
        applications(options).each do |application|
          
          stages(options, application).each do |stage| 
            
            nginx = self.class.new(application, stage)
            nginx.do_generate 
            
            unless options[:simulate]
              nginx.install_file
              if options[:enable] || @settings.stage(application, stage)[:active]
                nginx.enable
              else
                nginx.disable
              end
              nginx.restart
            end
            
          end
        end
      end
      
      private
      
      def do_generate
        
        exit_if_application_or_stage_doesnt_exist

        params = {
          app_root:  APP_ROOT,
          vhost: settings.stage(application, stage)[:vhost],
          application: application,
          stage: stage
        }

        contents = TEMPLATE
        %w(app_root application stage vhost).each do |param| 
          contents.gsub! "{{#{param.upcase}}}", params[param.to_sym].to_s
        end
        
        File.open(filename(application, stage),"w") do |file|
          file.write contents
        end
        
      end
      
      def filename
        File.join APP_ROOT, 'config', "nginx_#{application.to_s}_#{stage.to_s}"
      end
      
      def nginx_filename
        File.join SITES_AVAILABLE, "nginx_#{application.to_s}_#{stage.to_s}"
      end
      
      def install_file
        FileUtils.cp filename(application, stage), nginx_filename(application, stage)
      end
      
      def enable
        filename = nginx_filename(application, stage)
        FileUtils.ln_sf filename, File.join(SITES_ENABLED, File.basename(filename))
      end
      
      def disable
        filename = nginx_filename(application, stage)
        FileUtils.rm File.join(SITES_ENABLED, File.basename(filename))
      end
      
      def restart
        `service nginx restart`
      end
      
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
          opts.on("-s", "--simulate", 
                  "Does not install files in /etc/nginx/sites-available/", "Default: false") { |v| options[:simulate] = v }
          opts.on("-e", "--enable", 
                  "enable vhost", "Default: active param") { |v| options[:enable] = v }
          opts.separator ""
         
          opts.on_tail("-h", "--help", "Shows this help message.") { puts opts; exit }
          
          opts.parse!(arguments)
        end
        options
      end
      
      
      def init_repo
        begin
          FileUtils.mkdir_p SITES_AVAILABLE
          FileUtils.mkdir_p SITES_ENABLED
        rescue Errno::EACCES
          puts "Permission Denied to create '#{SITES_AVAILABLE}', '#{SITES_ENABLED}'"
          puts "Run this command with sudo"
          exit 1
        end
      end
      
    end
  end
end