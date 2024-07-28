drop table if exists ways_vertices_pgr;

create table ways_vertices_pgr as (

    with nodes_filter as (
        select distinct on (osm_id) osm_id from (
            select original_source_node_id as osm_id from edges_pre
            union all
            select original_target_node_id as osm_id from edges_pre
        ) nodes
    )

    select
        id,
        id as osm_id,
        ST_X(ST_SetSRID(ST_MakePoint(lon / 10000000.0, lat / 10000000.0), 4326)) as lon,
        ST_Y(ST_SetSRID(ST_MakePoint(lon / 10000000.0, lat / 10000000.0), 4326)) as lat,

        -- These fields seem to be for storing topological connectivity information but they are always empty
        -- when using osm2pgrouting, just keep them for legacy compatibility
        null as eout,
        null as cnt,
        null as chk,
        null as ein,

        ST_SetSRID(ST_MakePoint(lon / 10000000.0, lat / 10000000.0), 4326) as the_geom
    from
        planet_osm_nodes n
    right join
        nodes_filter nf on (n.id = nf.osm_id)

);

alter table ways_vertices_pgr add primary key (id);
create index if not exists ways_vertices_pgr_geom_idx on ways_vertices_pgr using gist (the_geom);
