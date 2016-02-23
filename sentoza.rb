#!/usr/bin/env ruby

require 'sinatra'
configure { set :server, :puma }

module Sentoza
  class App < Sinatra::Base
  
    get '/hi' do
      "Hello World!"
    end

    run! if app_file == $0

  end
end
