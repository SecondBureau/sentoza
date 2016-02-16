#!/usr/bin/env ruby

require 'rugged'
require 'rugged/repository'

app = 'charbon'
github = 'SecondBureau/charbon'
environments = %w(production stagging)
branches = {:production => "production", :stagging => "master"}
remote = "origin"
path = "/home/deploy/apps/#{app}/src"

fetch = false
begin
  puts ""
  Rugged::Repository.clone_at("https://github.com/#{github}", path, {
    transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
     print "#{received_objects} / #{total_objects} objects \r"
    }
  })
  puts ""
  puts "finished"

rescue Exception => e
  fetch = true
end

repo = Rugged::Repository.new(path)

if fetch {
puts "fetching"
remote = repo.remotes[remote]
remote.fetch({
  transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
  print "#{received_objects} / #{total_objects} objects \r"
  }
})
puts "\n fetched"
}