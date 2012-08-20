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

    def environment=(value)
      @config = nil
      @environment = value
    end
  end


  attr_reader :indexer

  def initialize
    @indexer = Indexer.new
  end

  def run(indexer_options = {})
    indexer.setup(indexer_options)
    indexer.start
  end

end
