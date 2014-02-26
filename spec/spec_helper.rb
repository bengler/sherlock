require 'simplecov'

SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.add_filter 'integration'
SimpleCov.add_filter 'coverage'
SimpleCov.start

$:.unshift(File.dirname(File.dirname(__FILE__)))
ENV['RACK_ENV'] = 'test'

require 'config/environment'
require 'sherlock'
require 'pebblebed/rspec_helper'
require 'memcache_mock'

set :environment, :test

RSpec.configure do |c|
  c.around(:each) do |example|
    clear_cookies if respond_to?(:clear_cookies)
    $memcached = MemcacheMock.new
    Pebblebed.memcached = $memcached
    example.run
  end
end

