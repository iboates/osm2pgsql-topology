#!/bin/bash

set -e

PBF_FILE=$1

docker compose exec postgis \
  psql \
  -d o2p_topo \
  -U o2p_topo \
  -c "create extension if not exists postgis; create extension if not exists pgrouting;"

docker compose exec postgis \
  psql \
  -d o2p_topo \
  -U o2p_topo \
  -c "create schema if not exists osm2pgr;"

docker compose run --rm -v $(pwd)/data:/data osm2pgrouting \
  -c /usr/share/osm2pgrouting/mapconfig.xml \
  -d o2p_topo \
  -U o2p_topo \
  -h postgis \
  -p 5432 \
  -W o2p_topo \
  --clean \
  --schema osm2pgr \
  -f /mnt/data.osm