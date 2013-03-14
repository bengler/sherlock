require 'thor'

module Sherlock

  class CLI < Thor

    desc "drop_all_indices", "Drop all Elasticsearch indices"
    def drop_all_indices
      require_relative '../config/environment'
      if ENV['RACK_ENV'] == 'production'
        puts "You're in production, you shouldn't do that."
        return
      end

      indices = Sherlock::Elasticsearch.server_status['indices'].keys
      puts "No indices to drop." if indices.empty?
      indices.each do |index|
        drop_index index
      end
    end

    desc "drop_index", "Drop a single index in Elasticsearch, index name should be on this format: sherlock_staging_apdm"
    def drop_index(index)
      require_relative '../config/environment'
      if Sherlock::Elasticsearch.delete_index(index, false)
        puts "Poof! Dropped index #{index}!"
      else
        puts "Index unknown: \"#{index}\" :-/"
      end
    end

    desc "purge_all_queues", "Empties all rabbitmq queues of waiting messages"
    def purge_all_queues
      if ENV['RACK_ENV'] == 'production'
        puts "You're in production, you shouldn't do that."
        return
      end

      require 'pebblebed'
      river = Pebblebed::River.new
      result = `rabbitmqctl list_queues`
      lines = result.split("\n")
      lines.shift
      lines.pop
      lines.each do |line|
        queue_name, count = line.split("\t")
        puts "Emptying #{count} messages from queue #{queue_name}..."
        begin
          river.queue(:name => queue_name).purge
          puts "Poof! Emptied queue #{queue_name} of #{count} messages"
        rescue => e
          puts "Unable to purge queue #{queue_name}. Error was: #{e}"
        end
      end
    end

    desc "delete_queue", "Delete a queue. Use when subscription params are going to change."
    def delete_queue(name)
      require 'pebblebed'
      river = Pebblebed::River.new
      queue = river.queue(:name => name)

      if queue.message_count > 0
        unless yes?("There are #{queue.message_count} messages #{name}. Proceed?", :red)
          say "The sun's not yellow it's chicken", :yellow
          return
        end
      end
      queue.purge
      queue.delete
      say "Queue #{name} was purged and deleted."
    end

    desc "blank_slate", "Empties all rabbitmq queues and drops all indexes"
    def blank_slate
      purge_all_queues
      drop_all_indices
    end

  end
end
