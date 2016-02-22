module Sentoza
  module UtilHelpers
    
    def log
      @log ||= Logger.new
    end
    
    def ln(target, source)
      FileUtils.rm_f source
      FileUtils.ln_sf Pathname.new(target).relative_path_from(Pathname.new(File.dirname(source))).to_s, source
    end
    
  end
end