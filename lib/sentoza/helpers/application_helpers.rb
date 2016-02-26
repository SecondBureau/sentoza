module Sentoza
  module ApplicationHelpers
    
    class BundleFailed < ::StandardError
      def message
        '`Bundle install` command failed.'
      end
    end 
    
    class AssetsPrecompileFailed < ::StandardError
      def message
        'rake task `assets:precompile` failed.'
      end
    end 
    
    class AssetsCleanFailed < ::StandardError
      def message
        'rake task `assets:clean` failed.'
      end
    end 
    
    class DbMigrateFailed < ::StandardError
      def message
        'rake task `db:migrate` failed.'
      end
    end 
    
    class DeployFailed < ::StandardError
      def message
        'Deployment has failed. Previous revision is still active.'
      end
    end
    
    APPS_PATH       = 'apps'
    CLONE_DIR       = 'src'
    SHARED_PATH     = '../shared' # relative to rails application root
    DATABASE_CONFIG = 'database.yml'
    PUMA_CONFIG     = 'puma.rb'
    CRON_DIR        = "tmp"
    MEDIA_DIR       = "media"
    
    attr_accessor :revision
    attr_accessor :restart
    
    def apps_path
      File.expand_path File.join(APP_ROOT, APPS_PATH)
    end
    
    def clone_path
      File.join(apps_path, application.name.to_s, CLONE_DIR)
    end
    
    def cron_path
      File.expand_path File.join(apps_path, CRON_DIR)
    end
    
    def repo
      @repo ||= Rugged::Repository.new(clone_path)
    end
    
    def stage_path
      File.join(apps_path, application.name.to_s, stage.name.to_s)
    end
    
    def current_root
      @current_root ||= File.join(apps_path, application.name.to_s, stage.name.to_s, 'current')
    end
    
    def repo_root
      File.dirname(@repo.path)
    end
    
    def app_root
      raise "Sentoza::ApplicationHelpers - 'revision' is null, can not set 'app_root' " if revision.nil?
      @app_root ||= File.join(stage_path, revision)
    end
    
    def shared_dir
      @shared_dir ||= File.expand_path(File.join(app_root, SHARED_PATH))
    end
    
    def appl_db_config_path
      File.join(app_root, 'config', DATABASE_CONFIG)
    end
    
    def shared_db_config_path
      File.join(shared_dir, DATABASE_CONFIG)
    end
    
    def appl_puma_path
      File.join(app_root, 'config', PUMA_CONFIG)
    end
    
    def shared_puma_path
      File.join(shared_dir, PUMA_CONFIG)
    end
    
    def appl_media_path
      File.join(app_root, 'public', MEDIA_DIR)
    end
    
    def shared_media_path
      File.join(shared_dir, MEDIA_DIR)
    end
    
    def appl_bundle_path
      File.join(app_root, '.bundle', 'config')
    end
    
    def shared_bundle_path
      File.join(shared_dir, "bundle.config")
    end
    
    def appl_rbenv_vars_path
      File.join(app_root, '.rbenv-vars')
    end
    
    def shared_rbenv_vars_path
      File.join(shared_dir, "rbenv-vars")
    end
    
    def appl_assets_path
      File.join(app_root, 'public', 'assets')
    end
    
    def shared_assets_path
      File.join(shared_dir, 'assets')
    end
    
    def init(params={})
      settings = Settings::Base.new
      application = params[:application]
      stage = params[:stage]
      branch = params[:branch]
      @application  = application.is_a?(Sentoza::Settings::Application) ? application : settings.find(application)
      @stage = @application.find_by_branch(branch) if branch
      if stage
        @stage = stage.is_a?(Sentoza::Settings::Stage) ? stage : @application.find(stage)
      end
      
    end
    
    def fetch
      log.info "Fetching latest revision..."
      begin
        remote = application.github.remote
        repo.remotes[remote].fetch({
          transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
            print "#{received_objects} / #{total_objects} objects \r"
          }
        })
        #distant_commit = repo.branches["#{remote}/#{stage.branch}"].target
        #repo.references.update(repo.head, distant_commit.oid)
        #oid = repo.rev_parse_oid('HEAD')
        #@revision = oid[0,7]
        log.info ["'#{application.name}' updated", :done]
      rescue Exception => e
        log.error ["#{e.message}", :failed]
      end
    end
    
    def merge
      log.info "Merging..."
      begin
        Dir.chdir(clone_path) do
          Bundler.clean_system "git merge #{application.github.remote}/#{stage.branch}"
        end
        oid = repo.rev_parse_oid('HEAD')
        @revision = oid[0,7]
        log.result :done
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
    end
    
    def checkout
      log.info "Checkout branch", true
      begin
        repo.checkout(stage.branch)
        oid = repo.rev_parse_oid('HEAD')
        @revision = oid[0,7]
        log.result :done
      rescue Rugged::ReferenceError 
        checkout_b
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
    end
    
    def checkout_b
      begin
        Dir.chdir(clone_path) do
          Bundler.clean_system "git checkout #{stage.branch}"
        end
      rescue
        raise "'git checkout #{stage.branch}' failed"
      end
    end
    
    def copy_tree
      log.info "Copying tree", true
      begin
        FileUtils.rm_rf app_root
        FileUtils.cp_r repo_root, app_root 
        FileUtils.rm_r("#{app_root}/.git", :force => true)
        log.result :done
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
    end
    
    def rename_failed_revision
      FileUtils.mv app_root, File.join(File.dirname(app_root), "#{File.basename(app_root)}-failed-#{Time.now.to_i}" )
    end
    
    def update_links
      log.info "Updating sym links", true
      begin
        FileUtils.mkdir_p File.dirname(appl_bundle_path)
        ln shared_db_config_path, appl_db_config_path
        ln shared_puma_path, appl_puma_path
        ln shared_bundle_path, appl_bundle_path
        ln shared_rbenv_vars_path, appl_rbenv_vars_path
        ln shared_assets_path, appl_assets_path
        ln shared_media_path, appl_media_path
        log.result :done
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
    end
    
    def activate_revision
      ln app_root, current_root
      @restart = true
    end
    
    def restart_puma_manager?
      restart
    end
    
    def restart_puma_manager(force=nil)
      log.info "Restarting Puma Manager.", true
      begin
        if force || restart_puma_manager?
          puts
          cmd = "stop puma app=#{current_root}"
          raise 'Bundler failed' unless Bundler.clean_system(cmd)
          cmd = "start puma app=#{current_root}"
          raise 'Bundler failed' unless Bundler.clean_system(cmd)
          log.info ["Puma restart", :done]
        else
          log.result :skipped
        end
      rescue Exception => e
        sudo_restart unless force
        log.error ["Puma restart", :failed]
        log.debug  cmd
      end
    end
    
    def sudo_restart
      FileUtils.mkdir_p cron_path unless File.exist? cron_path
      filename = File.join cron_path, "#{application.name}-#{stage.name}.restart"
      File.open(filename,"w") do |file|
        file.write "restart"
      end
    end
    
    def bundle(cmd, exception, result, context)
      log.info context
      begin
        Dir.chdir(app_root) do
          raise exception unless Bundler.clean_system("#{rbenv_init} #{cmd}")
        end
        log.info [result, :done]
      rescue Exception => e
        log.error [e.message, :failed]
        raise DeployFailed
      end
    end
    
    def rbenv_init
      'export PATH=/home/deploy/.rbenv/shims:/usr/sbin/rbenv:$PATH; eval "$(rbenv init -)"; '
    end
    
    def bundle_update
      bundle('bundle install', BundleFailed, 'Bundle done', 'Bundle install...')
    end
    
    def db_migrate
      bundle('bundle exec rake db:migrate', DbMigrateFailed, 'Db migrated', 'Db migrate...')
    end
    
    def assets_precompile
      bundle('bundle exec rake assets:precompile', AssetsPrecompileFailed, 'Assets precompiled', 'Precompile assets...')
    end
    
    def clean_assets
      bundle 'bundle exec rake assets:clean', AssetsCleanFailed, 'Old assets cleaned', 'Cleaning assets...'
    end
    
  end
  
end