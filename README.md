# Sherlock

Sherlock is a no-hassle service which handles all the indexing and query needs of a content-brokering Pebble [1].

## Sherlock has three interfaces

1. AMQP. Sherlock subscribes to a message queue. Incoming messages are evaluated, normalized and passed via…
2. ...HTTP requests to elasticsearch for indexing.
3. Accept client HTTP search queries, translate the query, pass it to elasticsearch and route the search result back to the client as an HTTP response.

## Installation

Sherlock needs two external services to function:

1. RabbitMQ [2]
2. elasticsearch [3]

### RabbitMQ

	brew install rabbitmq

### Elasticsearch

	brew install elasticsearch

Stop elasticsearch

	launchctl unload -wF ~/Library/LaunchAgents/homebrew.mxcl.elasticsearch.plist

Add these lines to your elasticsearch.yml ('brew info elasticsearch' to locate the file):

    # Turn off automatic index creation
    action.auto_create_index: false

Start elasticsearch

	launchctl load -wF ~/Library/LaunchAgents/homebrew.mxcl.elasticsearch.plist

### Sherlock

	git clone git@github.com:bengler/sherlock.git
	cd sherlock
	bundle install

Run the integration tests to see if Sherlock is playing well with RabbitMQ and elasticsearch

	rspec spec/integration/

Start the update listener

	./bin/update_listener start --daemon

## Usage

Index something:

  curl -XPUT 'http://localhost:9200/an_index_of_books/book/1' -d '{"title":"Island","author":"Aldous Huxley", "year_of_publication":"1962"}'

Also, anything added to grove, or updated in grove, will be put on the River, which Sherlock then picks up and sends to elasticsearch for indexing.

You can now do queries such as:

  http://sherlock.dev/api/sherlock/v1/search/an_index_of_books/*:*
  http://sherlock.dev/api/sherlock/v1/search/development/post.greeting:*?limit=100

## Other handy stuff

Drop all indexes

	./bin/sherlock drop_all_indices

Empty all queues of messages

	./bin/sherlock empty_all_queues

Test how text is analyzed

	curl -XGET 'localhost:9200/development_dna/_analyze' -d 'as sly as a fox'

[1] http://pebblestack.org

[2] http://rabbitmq.com

[3] http://elasticsearch.org

[4] http://www.elasticsearch.org/guide/reference/index-modules/analysis/standard-analyzer.html

