drop table if exists ways_vertices_pgr;

alter table edges_pre drop column if exists internal_node_ids2;
alter table edges_pre add column internal_node_ids2 bigint[];
UPDATE edges_pre SET internal_node_ids2 = string_to_array(internal_node_ids, ',')::bigint[];

create table ways_vertices_pgr as (

    -- Handle case where multiple ways share an internal node
    with shared_internal_nodes as (
        WITH unnested AS (
            SELECT unnest(internal_node_ids2) AS node_id
            FROM edges_pre
        )
        SELECT node_id as osm_id
        FROM unnested
        GROUP BY node_id
        HAVING COUNT(*) > 1
    ),

    -- Handle case where ways share a terminal node
    start_and_end_nodes as (
        select distinct on (osm_id) osm_id from (
            select original_source_node_id as osm_id from edges_pre
            union all
            select original_target_node_id as osm_id from edges_pre
        )
    ),

    -- Aggregate into single filter
    nodes_filter as (
        select
            *
        from
            shared_internal_nodes
        union
        select
            *
        from
            start_and_end_nodes
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
