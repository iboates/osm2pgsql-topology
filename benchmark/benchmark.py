from time import sleep

import geopandas as gpd
import pandas as pd
import sqlalchemy as sa


def main():

    engine = sa.create_engine('postgresql+psycopg2://o2p_topo:o2p_topo@localhost/o2p_topo')
    from_nodes_df = pd.read_sql("SELECT id as from_node FROM public.ways_vertices_pgr ORDER BY RANDOM() LIMIT 1000;", engine)
    to_nodes_df = pd.read_sql("SELECT id as to_node FROM public.ways_vertices_pgr ORDER BY RANDOM() LIMIT 1000;", engine)
    node_pairs_df = pd.concat([from_nodes_df, to_nodes_df], axis=1)

    with engine.connect() as conn:
        conn.execute(sa.text("drop table if exists public.route_result; drop table if exists pgr.route_result;"))
        conn.commit()

    for i, node_pair in node_pairs_df.iterrows():

        # osm2pgsql-topology
        gdf = gpd.read_postgis(sa.text(f"""
            with pgr_res as (
                SELECT * FROM pgr_dijkstra('SELECT gid as id, source, target, cost AS cost, reverse_cost AS reverse_cost from public.ways',
                {node_pair['from_node']}, {node_pair['to_node']}
                )
            )
            
            select
                {i} as trial,
                *
            from
                public.ways
            where
                gid in (select edge from pgr_res)
        """), engine, geom_col="the_geom")
        gdf.to_postgis("route_result", engine, schema="public", if_exists="replace")

        # osm2pgrouting
        gdf = gpd.read_postgis(sa.text(f"""
            with pgr_res as (
                SELECT * FROM pgr_dijkstra('SELECT gid as id, source, target, cost AS cost, reverse_cost AS reverse_cost from pgr.ways',
                (select id from pgr.ways_vertices_pgr where osm_id = {node_pair['from_node']}),
                (select id from pgr.ways_vertices_pgr where osm_id = {node_pair['to_node']})
                )
            )
    
            select
                {i} as trial,
                *
            from
                pgr.ways
            where
                gid in (select edge from pgr_res)
    """), engine, geom_col="the_geom")
        gdf.to_postgis("route_result", engine, schema="pgr", if_exists="replace")

        sleep(2)


if __name__ == "__main__":
    main()