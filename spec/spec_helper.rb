$:.unshift(File.dirname(File.dirname(__FILE__)))
ENV['RACK_ENV'] = 'test'

require 'config/environment'
require 'sherlock'
