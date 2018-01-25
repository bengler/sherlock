require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

LOGGER ||= Logger.new '/dev/null'

$:.unshift('./lib')
Dir.glob('./lib/**/*.rb').each { |lib| require lib }

TEST_RUNNING_ON_SEMAPHORE = !!ENV['SEMAPHORE']

environment = ENV['RACK_ENV'] || "development"
$memcached = Dalli::Client.new
Pebblebed.memcached = $memcached

Pebblebed.config do
  scheme 'http'
  service :checkpoint
end
