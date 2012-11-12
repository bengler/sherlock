require 'thor'

module Sherlock

  class CLI < Thor

    desc "drop_all_indices", "Drop all Elasticsearch indices"
    def drop_all_indices
      require_relative '../config/environment'
      indices = Sherlock::Elasticsearch.server_status['indices'].keys
      puts "No indices to drop." if indices.empty?
      indices.each do |index|
        drop_index index
      end
    end

    desc "drop_index", "Drop a single index in Elasticsearch"
    def drop_index(index)
      require_relative '../config/environment'
      Sherlock::Elasticsearch.delete_index(index, false)
      puts "Poof! Dropped index #{index}!"
    end

    desc "empty_all_queues", "Empties all rabbitmq queues of waiting messages"
    def empty_all_queues
      require 'pebblebed'
      river = Pebblebed::River.new
      result = `rabbitmqctl list_queues`
      lines = result.split("\n")
      lines.shift
      lines.pop
      lines.each do |line|
        queue_name, count = line.split("\t")
        river.queue(:name => queue_name).purge
        puts "Poof! Emptied queue #{queue_name} of #{count} messages"
      end
    end

    desc "blank_slate", "Empties all rabbitmq queues and drops all indexes"
    def blank_slate
      empty_all_queues
      drop_all_indices
    end

  end
end
