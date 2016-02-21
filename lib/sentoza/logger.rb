require 'colorize'

module Sentoza
  
  class Logger
    
    def initialize
    end
    
    def debug(msg, progress=false)
      log msg, 'debug', 0, progress
    end
    
    def info(msg, progress=false)
      log msg, 'info', 1, progress
    end
    
    def warning(msg, progress=false)
      log msg, 'warning', 2, progress
    end
    
    def error(msg, progress=false)
      log msg, 'error', 3, progress
    end
    
    def result(code)
      return unless code.is_a?(Symbol)
      colors= {
        failed: :red,
        done: :blue,
        skipped: :light_cyan
      }
      puts "[#{code.to_s}]".colorize(colors[code])
    end
    
    private
    
    def log(msg, prefix, level, progress)
      colors = [:light_cyan, :default, :yellow, :red]
      if msg.is_a?(Array)
        res = msg[1]
        msg = msg[0]
        progress = true
      end
      msg = "[#{prefix}]".colorize(colors[level]) + " #{msg}#{progress ? '...' : ''}".ljust(100)
      progress ? print(msg) : puts(msg)
      result res if res
    end
    
  end
  
end