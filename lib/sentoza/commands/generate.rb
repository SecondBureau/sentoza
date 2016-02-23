module Sentoza
  class Generate
    
    HELP_MESSAGE = <<-EOT
Usage: sentoza generate [ARGS]
Available generators:
 settings         generate config/sentoza.yml
 nginx            generate /etc/nginx/sites-available/[application]-[stage]
 applications     clone and install rails applications
 server           install sentoza server
 
EOT

    def self.settings(arguments)
      require_relative '../generator/settings'
      Sentoza::Generator::Settings.generate arguments
    end
  
    def self.nginx(arguments)
      require_relative '../generator/nginx'
      Sentoza::Generator::NGinx.run arguments
    end
  
    def self.applications(arguments)
      require_relative '../generator/applications'
      Sentoza::Generator::Applications.run arguments
    end
    
    def self.server(arguments)
      require_relative '../generator/server'
      Sentoza::Generator::Server.new.run
    end
    
    def self.help
      puts HELP_MESSAGE
    end
    
  end
end

