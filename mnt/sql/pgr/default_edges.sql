drop table if exists ways;

create table ways as (

    with _00_snap_nodes as (
        select
            ST_Snap(nodes.the_geom, edges.geom, 0.00001) as geom,
            edges.osm_id as snapped_to_edge_osm_id,
            nodes.the_geom as original_geom
        from
            ways_vertices_pgr as nodes,
            edges_pre as edges
        where
            ST_DWithin(nodes.the_geom, edges.geom, 0.00001)
    ),

    _01_group_snapped_nodes_by_edge_osm_id as (
        select
            ST_Collect(geom) as geom,
            snapped_to_edge_osm_id
        from
            _00_snap_nodes
        group by
            snapped_to_edge_osm_id
    ),

    _02_split_edges as (
        SELECT
            edges.osm_id AS edge_osm_id,
            (ST_Dump(ST_Split(edges.geom, nodes.geom))).geom AS split_geom,
            edges.*
        FROM
            edges_pre as edges,
            _01_group_snapped_nodes_by_edge_osm_id as nodes
        WHERE
            nodes.snapped_to_edge_osm_id = edges.osm_id
    ),

    _03_join_nodes_to_splitted_edges as (
        SELECT
            se.*,
            n_start.id AS source_node_id,
            n_end.id AS target_node_id
        FROM
            _02_split_edges se
        JOIN
            ways_vertices_pgr n_start ON ST_DWithin(ST_StartPoint(se.split_geom), n_start.the_geom, 0.00001)
        JOIN
            ways_vertices_pgr n_end ON ST_DWithin(ST_EndPoint(se.split_geom), n_end.the_geom, 0.00001)
    ),

    _04_final_output as (
        select

            -- osm2pgsql produces negative osm ids sometimes for some reason, apparently it's a legacy thing
            sqrt(power(osm_id, 2)),

            tag_id,
            ST_Length(split_geom) as length,

            -- From https://github.com/pgRouting/osm2pgrouting/blob/main/src/database/Export2DB.cpp (function fill_source_target)
            ST_length(geography(ST_Transform(split_geom, 4326))) as length_m,

            name,
            source_node_id as source,
            target_node_id as target,

            -- These used to be auto-generated in osm2pgrouting, we always use osm node ids by default, just hold onto them for legacy compatibility
            source_node_id as source_osm,
            target_node_id as target_osm,

            -- These appear to always just be the length
            ST_Length(split_geom) as cost,
            ST_Length(split_geom) as reverse_cost,

            -- From https://github.com/pgRouting/osm2pgrouting/blob/main/src/database/Export2DB.cpp (function fill_source_target)
            CASE WHEN one_way = -1 THEN
                -ST_length(geography(ST_Transform(split_geom, 4326))) / (maxspeed_forward::float * 5.0 / 18.0)
            ELSE
                ST_length(geography(ST_Transform(split_geom, 4326))) / (maxspeed_backward::float * 5.0 / 18.0)
            END as cost_s,
            CASE WHEN one_way = 1 THEN
                -ST_length(geography(ST_Transform(split_geom, 4326))) / (maxspeed_backward::float * 5.0 / 18.0)
            ELSE
                ST_length(geography(ST_Transform(split_geom, 4326))) / (maxspeed_backward::float * 5.0 / 18.0)
            END as reverse_cost_s,

            -- No idea what this is, no reference in osm2pgrouting repo, keep for legacy compatibility
            null as rule,

            one_way,
            oneway,
            ST_X(ST_StartPoint(split_geom)) as x1,
            ST_Y(ST_StartPoint(split_geom)) as y1,
            ST_X(ST_EndPoint(split_geom)) as x2,
            ST_Y(ST_EndPoint(split_geom)) as y2,
            maxspeed_forward,
            maxspeed_backward,
            priority,
            tags,
            split_geom as the_geom
        from
            _03_join_nodes_to_splitted_edges
    )

    select
        row_number() over () as gid,
        *
    from
        _04_final_output

);

drop table edges_pre;
alter table ways add primary key (gid);
create index if not exists ways_geom_idx on ways using gist (the_geom);
