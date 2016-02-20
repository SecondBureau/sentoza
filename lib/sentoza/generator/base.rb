require_relative '../settings'

module Sentoza
  module Generator
    class Base
      
      attr_accessor :settings, :application, :stage
      
      def initialize(application=nil, stage=nil)
        @application  = application
        @stage        = stage
      end
      
      def settings
        @settings ||= load_settings
      end
       
      def default(const)
        self.class.const_get("DEFAULT_#{const}".to_sym) rescue ""
      end
      
      def option(options, option_name, default="")
        return default unless (options && options.is_a?(Hash) && option_name && option_name.is_a?(Symbol))
        options.include?(option_name) ? options[option_name] : default
      end
      
      def load_settings
        Settings.new
      end
      
      def exit_if_application_or_stage_doesnt_exist
        if !settings.applications.include?(application)
          puts "Application '#{application.to_s}' does not exist"
          exit 1
        end
        if !settings.stages(application).include?(stage)
          puts "Stage '#{stage.to_s}' does not exist in application '#{application.to_s}'"
          exit 1
        end
      end
      
      def applications(options)
        options[:application] ? [options[:application].to_sym] : settings.applications
      end
      
      def stages(options, application)
        options[:stages] ? options[:stages] : settings.stages(application)
      end
      
    end
  end
end
