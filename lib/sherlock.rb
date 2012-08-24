Dir.glob('./lib/sherlock/**/*.rb').each { |lib| require lib }
require 'yaml'

module Sherlock

  class << self
    attr_reader :config, :indexer
  end

  @config = Sherlock::Config.new
  @indexer = Sherlock::Indexer.new

  def self.start_indexer
    @indexer.start
  end

end
