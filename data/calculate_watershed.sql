drop table if exists pgr_res;

create table pgr_res as (

with pgr_res as (

--SELECT *
--FROM pgr_dijkstra(
--  'SELECT id,
--          source_node_id as source, target_node_id as target,
--          st_length(geom) AS cost, st_length(geom) AS reverse_cost
--  FROM osm_edges',
--  3948020901, 3577226615,
--  directed => false
--)

SELECT * FROM pgr_kruskalDFS(
  'SELECT id, source_node_id as source, target_node_id as target,
  -1 AS cost, st_length(geom) AS reverse_cost
  from osm_edges',
  3577226615)

)

select
    *
from
    osm_edges
where
    id in (select edge from pgr_res)

    );