root = "#{Dir.getwd}"

bind "unix://#{root}/tmp/puma/socket"
stdout_redirect "#{root}/log/puma.stdout.log", "#{root}/log/puma.stderr.log", true
pidfile "#{root}/tmp/puma/pid"
state_path "#{root}/tmp/puma/state"
rackup "#{root}/config.ru"

workers 1
threads 4, 8

activate_control_app