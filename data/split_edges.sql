drop table if exists edges_split;

create table edges_split as (

    with _00_snap_nodes as (
        select
            ST_Snap(nodes.geom, edges.geom, 0.00001) as geom,
            edges.osm_id as snapped_to_edge_osm_id,
            nodes.geom as original_geom
        from
            nodes,
            edges
        where
            ST_DWithin(nodes.geom, edges.geom, 0.00001)
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
            edges,
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
            nodes n_start ON ST_DWithin(ST_StartPoint(se.split_geom), n_start.geom, 0.00001)
        JOIN
            nodes n_end ON ST_DWithin(ST_EndPoint(se.split_geom), n_end.geom, 0.00001)
    ),

    _04_final_output as (
        select
            osm_id,
            source_node_id,
            target_node_id,
            tags,
            split_geom as geom
        from
            _03_join_nodes_to_splitted_edges
    )

    select * from _04_final_output

)
