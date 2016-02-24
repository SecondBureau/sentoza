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
    
    attr_accessor :revision
    attr_accessor :restart
    
    def apps_path
      File.expand_path File.join(APP_ROOT, APPS_PATH)
    end
    
    def clone_path
      File.join(apps_path, application.name.to_s, CLONE_DIR)
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
    
    def init(application, stage)
      settings = Settings::Base.new
      @application  = application.is_a?(Sentoza::Settings::Application) ? application : settings.find(application)
      @stage = stage.is_a?(Sentoza::Settings::Stage) ? stage : @application.find(stage)
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
        distant_commit = repo.branches["#{remote}/#{stage.branch}"].target
        repo.references.update(repo.head, distant_commit.oid)
        oid = repo.rev_parse_oid('HEAD')
        @revision = oid[0,7]
        log.info ["'#{application.name}' updated", :done]
      rescue Exception => e
        log.error ["#{e.message}", :failed]
      end
    end
    
    def checkout
      log.info "Checkout branch", true
      begin
        repo.checkout(stage.branch)
        oid = repo.rev_parse_oid('HEAD')
        @revision = oid[0,7]
        log.result :done
      rescue Exception => e
        log.result :failed
        log.error e.message
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
        log.result :done
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
    end
    
    def activate_revision
      ln app_root, current_root
    end
    
    def restart_puma_manager?
      restart
    end
    
    def restart_puma_manager
      log.info "Restarting Puma Manager", true
      begin
        if restart_puma_manager?
          `restart puma-manager`
          log.result :done
        else
          log.result :skipped
        end
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
    end
    
    def bundle(cmd, exception, result, context)
      log.info context
      begin
        Dir.chdir(app_root) do
          raise exception unless Bundler.clean_system(cmd)
        end
        log.info [result, :done]
      rescue Exception => e
        log.error [e.message, :failed]
        raise DeployFailed
      end
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
    
  end
  
end