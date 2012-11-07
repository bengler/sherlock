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

Get RabbitMQ

	brew install rabbitmq

Get elasticsearch

	brew install elasticsearch	

Get Sherlock

	git clone git@github.com:bengler/sherlock.git
	cd sherlock
	bundle install

Run the integration tests to see if Sherlock is playing well with RabbitMQ and elasticsearch

	rspec spec/integration/
	

## Usage
* put stuff on river
* do query

## Handy elasticsearch stuff

Delete an index

	curl -XDELETE localhost:9200/development_dna

Create an index with a specified analyzer

	curl -XPUT 'localhost:9200/development_dna' -d '{"index":{"analysis":{"analyzer":{"default":{"type":"simple"}}}}}'

Test how text is tokenized

	curl -XGET 'localhost:9200/development_dna/_analyze' -d 'as sly as a fox'

[1] http://pebblestack.org

[2] http://rabbitmq.com

[3] http://elasticsearch.org

