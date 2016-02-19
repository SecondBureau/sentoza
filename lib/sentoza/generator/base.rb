module Sentoza
  module Generator
    class Base
       
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
