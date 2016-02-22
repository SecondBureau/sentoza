module Sentoza
  module ApplicationHelpers
    
    APPS_PATH       = '../apps'
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
      File.join(apps_path, application.to_s, CLONE_DIR)
    end
    
    def repo
      @repo ||= Rugged::Repository.new(clone_path)
    end
    
    def stage_path
      File.join(apps_path, application.to_s, stage.to_s)
    end
    
    def current_root
      @current_root ||= File.join(apps_path, application.to_s, stage.to_s, 'current')
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
    
    
    def checkout
      log.info "Checkout branch", true
      begin
        branch = settings.stage(application, stage)[:branch]
        repo.checkout(branch)
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
    
    def update_links
      log.info "Updating sym links", true
      begin
        FileUtils.mkdir_p File.dirname(appl_bundle_path)
        ln shared_db_config_path, appl_db_config_path
        ln shared_puma_path, appl_puma_path
        ln shared_bundle_path, appl_bundle_path
        ln app_root, current_root
        ln shared_rbenv_vars_path, appl_rbenv_vars_path
        log.result :done
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
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
    
    def ln(target, source)
      FileUtils.rm_f source
      FileUtils.ln_sf Pathname.new(target).relative_path_from(Pathname.new(File.dirname(source))).to_s, source
    end
    
    def bundle_update
      log.info "Bundler update", true
      begin
        Dir.chdir(current_root) do
          `bundle install`
        end
        log.result :done
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
    end
    
    def assets_precompile
      log.info "Precompile assets", true
      begin
        Dir.chdir(current_root) do
          `bundle exec rake assets:precompile`
        end
        log.result :done
      rescue Exception => e
        log.result :failed
        log.error e.message
      end
    end
    
  end
  
end