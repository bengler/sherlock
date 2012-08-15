require_relative './sherlock/pebble_store'
Dir.glob('./lib/sherlock/**/*.rb').each { |lib| require lib }
require 'yaml'

class Sherlock

  class << self
    def config
      unless @config
        path = File.expand_path(File.join(File.dirname(__FILE__), '../'))
        @config = YAML.load(File.read("#{path}/configure.yml"))[environment]
      end
      @config
    end

    def environment
      @environment ||= (ENV['RACK_ENV'] || 'development')
    end
  end

  attr_reader :stream_groups
  def initialize
    @stream_groups = []
  end

  def run
    stream_groups.each do |group|
      group.setup
      group.start
    end
  end

end
