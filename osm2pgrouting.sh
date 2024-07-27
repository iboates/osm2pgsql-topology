#!/bin/bash

set -e

PBF_FILE=$1

docker compose down
docker compose up -d

# TODO: I don't like how tr executes on the host machine
docker compose run --rm osmium \
  tags-filter /mnt/data/$PBF_FILE \
  --overwrite \
  -o /mnt/data/data_filtered.pbf \
   w/highway=$(tr '\n' ',' < mnt/tags/pgr/highway.txt | sed 's/,$/\n/') \
   w/cycleway=$(tr '\n' ',' < mnt/tags/pgr/cycleway.txt | sed 's/,$/\n/') \
   w/tracktype=$(tr '\n' ',' < mnt/tags/pgr/tracktype.txt | sed 's/,$/\n/') \
   w/junction=$(tr '\n' ',' < mnt/tags/pgr/junction.txt | sed 's/,$/\n/')

docker compose run --rm osmium \
  cat /mnt/data/data_filtered.pbf \
  --overwrite \
  -o /mnt/data/data_filtered.osm

docker compose exec postgis \
  psql \
  -d o2p_topo \
  -U o2p_topo \
  -c "create extension if not exists postgis; create extension if not exists pgrouting;"

docker compose run --rm osm2pgsql \
  -s \
  -d o2p_topo \
  -U o2p_topo \
  -H postgis \
  -P 5432 \
  -O flex \
  -S /mnt/style/osm2pgr_default.lua \
  /mnt/data/andorra-latest.osm.pbf

docker compose exec postgis \
  psql \
  -d o2p_topo \
  -U o2p_topo \
  -f /mnt/sql/pgr/default_nodes.sql

docker compose exec postgis \
  psql \
  -d o2p_topo \
  -U o2p_topo \
  -f /mnt/sql/pgr/default_edges.sql

docker compose exec postgis \
  psql \
  -d o2p_topo \
  -U o2p_topo \
  -c "create schema if not exists pgr;"

docker compose run --rm -v $(pwd)/data:/data osm2pgrouting \
  -c /usr/share/osm2pgrouting/mapconfig.xml \
  -d o2p_topo \
  -U o2p_topo \
  -h postgis \
  -p 5432 \
  -W o2p_topo \
  --clean \
  --schema pgr \
  -f /mnt/data/data_filtered.osm