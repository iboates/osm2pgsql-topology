drop table if exists pgr_res;
create table pgr_res as (
  with pgr_res as (
--    SELECT * FROM pgr_kruskalDFS(
--      'SELECT id, target_node_id as source, source_node_id as target,
--      st_length(geom) AS cost
--      from osm_edges',
--      2132557864)
SELECT * FROM pgr_drivingDistance(
  'SELECT id, target_node_id as source, source_node_id as target,
  st_length(geom) as cost FROM osm_edges',
  53275598, 99999999, directed => true)
  )
  select
    *
  from
    osm_edges
  where
    id in (select edge from pgr_res)
);