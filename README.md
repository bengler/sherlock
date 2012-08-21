sherlock
========

Sherlock is the glue between various pebbles and elastic search.


Sherlock does three things
--------------------------

1. Listen to the river message queue from grove (and other pebbles later on).
2. Update elastic search index with changes mentioned in said river.
3. Accept search queries (http), redirect them to elastic search and route the search result back.
4. ..while running as a daemon


Usage
-----

Dependencies:
- grove (or some other service providing data to river)
- pebblebed
- rabbitmq (brew install rabbitmq)
- elasticsearch (brew install elasticsearch)
