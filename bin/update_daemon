#!/usr/bin/env ruby
require './config/environment.rb'

adapter = Class.new do
  def configure_start_command(command)
    command.option :verbose, '-v', '--verbose', 'Be verbose.'
  end

  def on_start(options, helper)
    puts "on_start #{options.inspect}"
  end

  def configure_supervisor(supervisor)
    options = {
      name: 'sherlock.index',
      :path => '**',
      :klass => 'post.*|unit|organization|group|capacity|associate|affiliation',
      :event => 'create|update|exists|delete',
    }
    supervisor.add_listener(Sherlock::UpdateListener.new, options)
  end
end.new

daemon = Pebbles::River::DaemonHelper.new(adapter, logger: LOGGER)
daemon.run
