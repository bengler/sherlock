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
