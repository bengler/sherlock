# Sherlock

Sherlock is the glue between various pebbles and elastic search.


## Sherlock does three things

1. Listen to the river message queue from grove (and other pebbles later on).
2. Update elastic search index with changes mentioned in said river.
3. Accept search queries (http), redirect them to elastic search and route the search result back.


## TODO

- Rebuild es index.
- Checkpoint authentication and filtered search result.
- ..or just disregard restricted posts until we need more fancy authentication.


## Usage

Sherlock needs this to run:

- grove (or some other service providing data to river)
- pebblebed
- rabbitmq (brew install rabbitmq)
- elasticsearch (brew install elasticsearch)


## ElasticSearch Notes

We can filter against fields that explicitly do not exist
http://www.elasticsearch.org/guide/reference/query-dsl/missing-filter.html
