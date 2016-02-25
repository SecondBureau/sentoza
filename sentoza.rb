#!/usr/bin/env ruby

require 'sinatra'
require 'json'

configure { set :server, :puma }

module Sentoza
  class App < Sinatra::Base
  
    get '/hi' do
      "Hello World!"
    end
    
    post '/hooks/github' do
      push = JSON.parse(request.body.read)
      application = push["repository"]["name"]
      branch = File.basename(push["ref"])
      app_root = File.expand_path(File.dirname(__FILE__))
      cmd = "bin/sentoza deploy -a #{application} -b #{branch} >> #{File.join(app_root, "log", "github_hooks.log")} &"
      Dir.chdir(app_root) do
        Bundler.clean_system cmd
      end
    end

    run! if app_file == $0

  end
end
