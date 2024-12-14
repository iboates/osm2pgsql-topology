#!/bin/bash

PBF=$1
STYLE_FILE=$2

docker compose exec postgis \
  psql \
  -d o2p_topo \
  -U o2p_topo \
  -c "create extension if not exists postgis; create extension if not exists pgrouting;"

docker compose run --rm -v $(pwd)/mnt:/mnt osm2pgsql -s -d o2p_topo -U o2p_topo -H postgis -P 5432 -O flex -S $STYLE_FILE $PBF
docker compose exec postgis psql -d o2p_topo -U o2p_topo -f /mnt/sql/pgr/default_nodes.sql
docker compose exec postgis psql -d o2p_topo -U o2p_topo -f /mnt/sql/pgr/default_edges.sql