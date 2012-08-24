sherlock
========

Sherlock is the glue between various pebbles and elastic search.


Sherlock does three things
--------------------------

1. Listen to the river message queue from grove (and other pebbles later on).
2. Update elastic search index with changes mentioned in said river.
3. Accept search queries (http), redirect them to elastic search and route the search result back. Audit result(using checkpoint) before return.


Other features needed 
---------------------
- Sherlock indexer should run as a daemon
- Need a way to rebuild the index (from grove etc)
- Use checkpoint for filtering access

Usage
-----

Dependencies:
- grove (or some other service providing data to river)
- pebblebed
- rabbitmq (brew install rabbitmq)
- elasticsearch (brew install elasticsearch)
