# A daemon to feed Sherlock with content updates from Grove, which is then passed on to elasticsearch for indexing

module Sherlock

  class ContentListenerDaemon < Servolux::Server
    NAME = "sherlock_content_listener"
    def initialize(opts)
      @listener = nil
      super(NAME, opts)
    end

    def before_starting
      @listener = Sherlock::Indexer.new
    end

    def after_starting
      logger.info 'Running'
    end

    def before_stopping
      return unless @listener
      @listener, listener = nil, @listener
      listener.stop
      Thread.pass  # allow the server thread to wind down
    end

    def after_stopping
      logger.info 'Stopped'
    end

    def run
      @listener.start
      sleep
    rescue StandardError => e
      if logger.respond_to?:exception
        logger.exception(e)
      else
        logger.error(e.inspect)
        logger.error(e.backtrace.join("\n"))
      end
    end
  end

end