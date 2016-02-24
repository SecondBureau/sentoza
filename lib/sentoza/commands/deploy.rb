require_relative '../settings'
require_relative '../generator/applications'
require_relative '../helpers/application_helpers'
require_relative '../helpers/util_helpers'



module Sentoza
  
  class NothingToDo < ::StandardError; end
  
  class Deploy < Sentoza::Command
    
    include ApplicationHelpers
    include UtilHelpers
    
    attr_accessor :settings, :application, :stage
    attr_accessor :previous_revision
    attr_accessor :force_build
    
    def self.run(arguments)
      options = parse_arguments(arguments)
      Sentoza::Deploy.new(options[:application], options[:stage], options[:force]).run!
    end
    
    def initialize(application, stage, force=false)
      init application, stage
      @force_build  = force
    end
    
    def run!
      log.info "Deploying #{application.name}-#{stage.name}..."
      begin
        checkout
        @previous_revision = revision
        fetch
        merge
        raise NothingToDo, "Sources are identical. Build is canceled" if (revision.eql?(previous_revision) && !force_build && File.exist?(app_root))
        copy_tree
        update_links
        bundle_update
        assets_precompile
        #db_migrate
        activate_revision
        log.info ["deployment successful. Revision #{revision} is now active", :success]
      rescue NothingToDo => e
        log.warning e.message
      rescue DeployFailed => e
        rename_failed_revision
        log.warning e.message
      rescue Exception => e
        log.error e.message
      end
      
    end
    
    private

    def self.parse_arguments(arguments)
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: sentoza deploy [options]"
        opts.separator ""
        opts.on("-a", "--application=NAME", String,
                "Name of the application to deploy.", "Required") { |v| options[:application] = v }
        opts.on("-s", "--stage=STAGE", String,
                "Stage to deploy.", "Required") do |v| 
                  options[:stage] = v
                end
        opts.separator ""
        opts.on("-f", "--force", TrueClass,
                "Force rebuild even if revision hasn't changed.", "Default: False") { |v| options[:force] = v }
        opts.on_tail("-h", "--help", "Shows this help message.") { puts opts; exit }
        
        opts.parse!(arguments)
        
        raise OptionParser::MissingArgument if options[:application].nil?
        raise OptionParser::MissingArgument if options[:stage].nil?
      end
      options
    end
    
  end
end