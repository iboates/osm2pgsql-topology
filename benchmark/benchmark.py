from time import sleep

import geopandas as gpd
import pandas as pd
import sqlalchemy as sa
from tqdm import tqdm


def main():

    engine = sa.create_engine('postgresql+psycopg2://o2p_topo:o2p_topo@postgis:5432/o2p_topo')
    from_nodes_df = pd.read_sql("SELECT id as from_node FROM public.ways_vertices_pgr ORDER BY RANDOM() LIMIT 1000;", engine)
    to_nodes_df = pd.read_sql("SELECT id as to_node FROM public.ways_vertices_pgr ORDER BY RANDOM() LIMIT 1000;", engine)
    node_pairs_df = pd.concat([from_nodes_df, to_nodes_df], axis=1)

    with engine.connect() as conn:
        conn.execute(sa.text("drop table if exists public.route_result; drop table if exists osm2pgr.route_result;"))
        conn.commit()

    for i, node_pair in tqdm(node_pairs_df.iterrows(), total=node_pairs_df.shape[0], desc="Comparing routes"):

        # osm2pgsql-topology
        gdf = gpd.read_postgis(sa.text(f"""
            with pgr_res as (
                SELECT * FROM pgr_dijkstra('SELECT gid as id, source, target, cost AS cost, reverse_cost AS reverse_cost from public.ways',
                {node_pair['from_node']}, {node_pair['to_node']}
                )
            )
            
            select
                to_timestamp({i}) as trial,
                *
            from
                public.ways
            where
                gid in (select edge from pgr_res)
        """), engine, geom_col="the_geom")
        if not gdf.empty:
            gdf.to_postgis("route_result", engine, schema="public", if_exists="append")

        # osm2pgrouting
        gdf = gpd.read_postgis(sa.text(f"""
            with pgr_res as (
                SELECT * FROM pgr_dijkstra('SELECT gid as id, source, target, cost AS cost, reverse_cost AS reverse_cost from osm2pgr.ways',
                (select id from osm2pgr.ways_vertices_pgr where osm_id = {node_pair['from_node']}),
                (select id from osm2pgr.ways_vertices_pgr where osm_id = {node_pair['to_node']})
                )
            )
    
            select
                to_timestamp({i}) as trial,
                *
            from
                osm2pgr.ways
            where
                gid in (select edge from pgr_res)
    """), engine, geom_col="the_geom")
        if not gdf.empty:
            gdf.to_crs(4326).to_postgis("route_result", engine, schema="osm2pgr", if_exists="append")

        # sleep(2)


if __name__ == "__main__":
    main()