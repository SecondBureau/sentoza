module Sentoza
  class Generate
    
    HELP_MESSAGE = <<-EOT
Usage: sentoza generate [ARGS]
Available generators:
 config         generate config/sentoza.yml
 nginx          generate /etc/nginx/sites-available/[application]-[stage]
 applications   clone and install rails applications
 
EOT

  def self.config(arguments)
    require_relative '../generator/config'
    Sentoza::Generator::Config.new.generate arguments
  end
  
  def self.nginx(arguments)
    require_relative '../generator/nginx'
    Sentoza::Generator::NGinx.new.generate arguments
  end
  
  def self.applications(arguments)
    require_relative '../generator/applications'
    Sentoza::Generator::Applications.new.install arguments
  end
    
    
    def self.help
      puts HELP_MESSAGE
    end
    
  end
end

