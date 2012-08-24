
module Sherlock

  class Config
    attr_reader :environment, :services

    def initialize
      @environment = ENV['RACK_ENV'] || "development"
      @services = YAML::load(File.open("config/services.yml"))[@environment]
      self
    end

  end
end
