# Sherlock

Sherlock is a no-hassle service which handles all the indexing and query needs of a content-brokering Pebble [1]. Sherlock is the glue between pebbles applications and elasticsearch. 

## Sherlock has three interfaces

1. AMQP. Sherlock subscribes to a message queue. Incoming messages are evaluated, normalized and passed via…
2. HTTP requests to elasticsearch for indexing the content.
3. Accept HTTP search queries, translate the query, passe it to elasticsearch and route the search result back to the client as an HTTP response.

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

[1] http://pebblestack.org

[2] http://rabbitmq.com

[3] http://elasticsearch.org

