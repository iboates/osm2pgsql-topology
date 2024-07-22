drop table if exists nodes;

create table nodes as (

    with nodes_filter as (
        select distinct on (osm_id) osm_id from (
            select original_source_node_id as osm_id from edges
            union all
            select original_target_node_id as osm_id from edges
        ) nodes
    )

    select
        id,
        ST_SetSRID(ST_MakePoint(lon / 10000000.0, lat / 10000000.0), 4326) as geom,
        tags
    from
        planet_osm_nodes n
    right join
        nodes_filter nf on (n.id = nf.osm_id)

);

create index if not exists nodes_geom_idx on nodes using gist (geom);
