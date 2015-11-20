# Sherlock
  ____  _               _            _    
 / ___|| |__   ___ _ __| | ___   ___| | __
 \___ \| '_ \ / _ \ '__| |/ _ \ / __| |/ /
  ___) | | | |  __/ |  | | (_) | (__|   <
 |____/|_| |_|\___|_|  |_|\___/ \___|_|\_\

[![Build Status](https://semaphoreapp.com/api/v1/projects/ef5dcc4d6e420430033d8928194536f7784316e1/28278/badge.png)](https://semaphoreapp.com/projects/1579/branches/28278)

Sherlock is a no-hassle service which handles all the indexing and query needs of a content-brokering [Pebble] [1]. For example, consider using Sherlock if you need to full-text query [Grove] [4] content.

## Warning: Experimental software

Sherlock is currently used by several pebbles in production, but the API is still under continous development so expect both behavior and interfaces to change.

## Sherlock has three interfaces

1. AMQP. Sherlock subscribes to a message queue. Incoming messages are evaluated, normalized and passed via…
2. ...HTTP requests to Elasticsearch for indexing.
3. Accept client HTTP search queries, translate the query, pass it to Elasticsearch and route the search result back to the client as an HTTP response.

## Installation

Sherlock needs two external services to function:

1. [RabbitMQ] [2]
2. [Elasticsearch] [3]

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

Run the integration tests to see if Sherlock is playing well with RabbitMQ and Elasticsearch

	rspec spec/integration/

Start the update listener

	./bin/update_listener start --daemon

## Usage

Index something:

	curl -XPUT 'http://localhost:9200/an_index_of_books/book/1' -d '{"title":"Island","author":"Aldous Huxley", "year_of_publication":"1962"}'

Also, anything added to grove, or updated in grove, will be put on the River, which Sherlock then picks up and sends to Elasticsearch for indexing.

You can now do queries such as:

	http://sherlock.dev/api/sherlock/v1/search/my_index/*:*/?q=foo+bar
	http://sherlock.dev/api/sherlock/v1/search/my_index/*:*
	http://sherlock.dev/api/sherlock/v1/search/development/post.greeting:*?limit=100


## Predefined mappings

Some use-cases require predefined mappings. E.g. we don't want a UID to be string-tokenized because this will cause dash to look like a whitespace and thus not return hits on a query.

If you need to predefine how ES analyzes a particular part of you data, do so by appending your stuff to `config/predefined_es_mappings.json`.


## Other handy stuff

Drop all indexes

	./bin/sherlock drop_all_indices

Empty all queues of messages

	./bin/sherlock empty_all_queues

...or you can also scratch the queue itself with

	rabbitmqadmin purge queue=response.report.river

Test how text is analyzed

	curl -XGET 'localhost:9200/development_dna/_analyze' -d 'as sly as a fox'

Type mapping of fields in an index

	curl -XGET 'http://localhost:9200/sherlock_development_apdm/_mapping'


[1]:	http://pebblestack.org	"Pebblestack"

[2]:	http://rabbitmq.com		"Rabbitmq"

[3]: http://elasticsearch.org	"Elasticsearch"

[4]: https://github.com/bengler/grove	"Grove"
