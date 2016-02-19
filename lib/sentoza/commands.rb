ARGV << '--help' if ARGV.empty?

aliases = {
  "d"  => "deploy",
  "t"  => "test",
  "g"  => "generate"
}

command = ARGV.shift
command = aliases[command] || command

require_relative 'command'


Sentoza::Command.run(command, ARGV)