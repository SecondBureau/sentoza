module Sentoza
  # This is a class which takes in a Senotza command and initiates the appropriate
  # initiation sequence.
  #
  # Warning: This class mutates ARGV because some commands require manipulating
  # it before they are run.
  class CommandsTasks # :nodoc:


    attr_reader :argv

    HELP_MESSAGE = <<-EOT
Usage: sentoza COMMAND [ARGS]
The most common Sentoza commands are:
 deploy      deploy an app (short-cut alias: "d")
 generate    generate files (short-cut alias: "g")
 
All commands can be run with -h (or --help) for more information.
In addition to those commands, there are:
EOT

    ADDITIONAL_COMMANDS = [
      [ 'test', 'Tests (short-cut alias: "t")' ],
      [ 'version', 'Get Version']
    ]

    COMMAND_WHITELIST = %w(deploy help test version generate)

    def initialize(argv)
      @argv = argv
    end

    def run_command!(command)
      command = parse_command(command)
      if COMMAND_WHITELIST.include?(command)
        send(command)
      end
    end
    
    def generate
      require_command!("generate")
      if %w(-h --help).include?(argv.first)
        Sentoza::Generate.help
      else
        Sentoza::Generate.send(shift_argv!, argv)
      end      
      
    end

    def deploy
      require_command!("deploy")
    end

    def test
      require_command!("test")
    end

    def version
      argv.unshift '--version'
      require_command!("version")
    end

    def help
      write_help_message
      write_commands ADDITIONAL_COMMANDS
    end

    private

      def shift_argv!
        argv.shift if argv.first && argv.first[0] != '-'
      end

      def require_command!(command)
        require_relative "#{command}"
      end

      # Change to the application's path 
      def set_application_directory!
        Dir.chdir(File.expand_path('../../', APP_PATH))
      end

      def write_help_message
        puts HELP_MESSAGE
      end

      def write_commands(commands)
        width = commands.map { |name, _| name.size }.max || 10
        commands.each { |command| printf(" %-#{width}s   %s\n", *command) }
      end

      def parse_command(command)
        case command
        when '--version', '-v'
          'version'
        when '--help', '-h'
          'help'
        else
          command
        end
      end
  end
end