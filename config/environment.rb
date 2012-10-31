require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

LOGGER ||= Logger.new '/dev/null'

$:.unshift('./lib')

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

environment = ENV['RACK_ENV'] || "development"

Pebblebed.config do
  service :checkpoint
end
