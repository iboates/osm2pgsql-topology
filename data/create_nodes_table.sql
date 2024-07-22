drop table if exists osm_nodes;

create table osm_nodes as (

    with nodes_filter as (
        select distinct on (osm_id) osm_id from (
            select original_source_node_id as osm_id from edges_pre
            union all
            select original_target_node_id as osm_id from edges_pre
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

alter table osm_nodes add primary key (id);
create index if not exists nodes_geom_idx on osm_nodes using gist (geom);
