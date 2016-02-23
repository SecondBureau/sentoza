require_relative 'base'
require_relative 'nginx'

module Sentoza
  module Generator
    class Server < Sentoza::Generator::Base
      
      TEMPLATE = <<-EOT
      
upstream sentoza {
  server unix:///{{root}}/tmp/puma/socket;
}

server {
  listen 80;
  server_name sentoza.cid.siz.yt;

  root /{{root}}/public;
  access_log /{{root}}/log/nginx.access.log;
  error_log /{{root}}/log/nginx.error.log info;

  location / {
    try_files $uri/index.html $uri @sentoza;
  }

  location @sentoza {
    include proxy_params;
    proxy_pass http://sentoza;
  }
  
  error_page 500 502 503 504 /500.html;
  error_page 404 /404.html;
}
      
EOT

      attr_accessor :root
      
      def initialize
        
      end
      
      def run
        @root = "#{Dir.getwd}"
        mk_dir
        mk_config_file
        sites_available = Sentoza::Generator::NGinx::SITES_AVAILABLE
        sites_enabled   = Sentoza::Generator::NGinx::SITES_ENABLED
        puts "echo '#{root}' >> /etc/puma.conf"
        puts "cp #{File.join(root, 'tmp', 'sentoza')} #{sites_available}"
        puts "ln -s ../#{File.basename(sites_available)}/sentoza #{File.join(sites_enabled, 'sentoza')}"
        puts "restart puma-manager"
        puts "service nginx restart"
      end
      
      private
      
      def mk_dir
        FileUtils.mkdir_p File.join(root, 'log')
        FileUtils.mkdir_p File.join(root, 'tmp', 'puma')
      end
      
      def mk_config_file
        contents = TEMPLATE.gsub "{{root}}", root
        File.open(File.join(root, 'tmp', 'sentoza'),"w") do |file|
          file.write contents
        end
      end
    
    
    end
  end
end