#!/usr/bin/env ruby

require 'sinatra'
configure { set :server, :puma }

module Sentoza
  class App < Sinatra::Base
  
    get '/hi' do
      "Hello World!"
    end
    
    post '/hooks/github' do
      push = JSON.parse(request.body.read)
      puts "I got some JSON: #{push.inspect}"
    end

    run! if app_file == $0

  end
end
