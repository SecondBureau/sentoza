require_relative '../helpers/util_helpers'
require_relative '../helpers/config_helpers'
require_relative '../helpers/application_helpers'

module Sentoza
  module Generator
    class Base
      
      include UtilHelpers
      include ConfigHelpers
      include ApplicationHelpers
      
      attr_accessor :application, :stage
      
      class << self
        
        def run(arguments)
          options = parse_arguments(arguments)
          Settings::Base.applications(options).each do |application|
            begin
              Settings::Base.stages(options, application).each do |stage| 
                self.new(application, stage).run! options
              end
            rescue Sentoza::Settings::ApplicationNotFound => e
              Logger.new.error e
            end
          end
        end

      end
      
      def initialize(application=nil, stage=nil)
        init({application: application, stage: stage})
      end
       
      def default(const)
        self.class.const_get("DEFAULT_#{const}".to_sym) rescue ""
      end
      
      def option(options, option_name, default="")
        return default unless (options && options.is_a?(Hash) && option_name && option_name.is_a?(Symbol))
        options.include?(option_name) ? options[option_name] : default
      end
      
  
    end
  end
end
