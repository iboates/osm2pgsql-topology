#!/bin/bash

docker compose run --rm -v $(pwd)/data:/data osm2pgsql -s -E 4326 -d o2p_topo -U o2p_topo -H postgis -P 5432 -O flex -S /data/style.lua /data/data.pbf
docker compose exec postgis psql -d o2p_topo -U o2p_topo -c "$(cat data/create_nodes_table.sql)"
docker compose exec postgis psql -d o2p_topo -U o2p_topo -c "$(cat data/split_edges.sql)"