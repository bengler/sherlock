#!/usr/bin/env ruby
require './config/environment.rb'


QueueListener = Class.new do
  def call(message)
    LOGGER.info "message #{message.inspect}"
    puts "message #{message.inspect}"
    nil
  end
end


adapter = Class.new do
  def configure_start_command(command)
    command.option :verbose, '-v', '--verbose', 'Be verbose.'
  end

  def on_start(options, helper)
    puts "on_start #{options.inspect}"
    puts "  verbose? #{options[:verbose].inspect}"
  end

  def configure_supervisor(supervisor)
    options = {
      name: 'sherlock.index',
      :path => '**',
      :klass => 'post.*|unit|organization|group|capacity|associate|affiliation',
      :event => 'create|update|exists|delete',
    }
    supervisor.add_listener(QueueListener.new, options)
  end
end.new

daemon = Pebbles::River::DaemonHelper.new(adapter, logger: LOGGER)
daemon.run
