require_relative '../settings'
require_relative '../generator/applications'
require_relative '../helpers/application_helpers'

module Sentoza
  class Deploy < Sentoza::Command
    
    include ApplicationHelpers
    
    attr_accessor :settings, :application, :stage
    attr_accessor :previous_revision
    attr_accessor :force_build
    
    def self.run(arguments)
      options = parse_arguments(arguments)
      Sentoza::Deploy.new(:charbon, :staging, options[:force]).run!
    end
    
    def initialize(application=nil, stage=nil, force=false)
      @application  = application
      @stage        = stage
      @settings     = Settings.new
      @force_build  = force
    end
    
    def run!
      log.info "Deploying #{application}-#{stage}..."
      checkout
      @previous_revision = revision
      fetch
      if revision.eql?(previous_revision) && !force_build
        log.warning "Sources are identical. Build is canceled"
        exit 0
      end
      copy_tree
      update_links
      bundle_update
      assets_precompile
    end
    
    private
    
    def fetch
      log.info "Fetching latest revision..."
      begin
        remote = settings.github(application)[:remote]
        branch = settings.stage(application, stage)[:branch]
        repo.remotes[remote].fetch({
          transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
            print "#{received_objects} / #{total_objects} objects \r"
          }
        })
        distant_commit = repo.branches["#{remote}/#{branch}"].target
        repo.references.update(repo.head, distant_commit.oid)
        oid = repo.rev_parse_oid('HEAD')
        @revision = oid[0,7]
        log.info ["'#{application}' updated", :done]
      rescue Exception => e
        log.error ["#{e.message}", :failed]
      end
    end

    def self.parse_arguments(arguments)
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: sentoza deploy [options]"
        opts.separator ""
        opts.on("-a", "--application=NAME", String,
                "Name of the application to deploy.", "Default: None") { |v| options[:application] = v }
        opts.on("-s", "--stage=STAGE", String,
                "Stages for this application.", "Default: None") do |v| 
                  options[:stages] ||= []
                  options[:stages] << v.to_sym
                end
        opts.separator ""
        opts.on("-f", "--force", TrueClass,
                "Force rebuild even if revision hasn't changed.", "Default: False") { |v| options[:force] = v }
        opts.on_tail("-h", "--help", "Shows this help message.") { puts opts; exit }
        
        opts.parse!(arguments)
      end
      options
    end
    
  end
end