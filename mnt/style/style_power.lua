POWER_TAGS = {
    'line',
    'minor_line',
    'cable'
}

function isInSet(value, set)
    for _, v in ipairs(set) do
        if v == value then
            return true
        end
    end
    return false
end

local node_tags = osm2pgsql.define_table({
    name = 'node_tags',
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'tags', type = 'json' },
    }
})

local edges = osm2pgsql.define_table({
    name = 'edges_pre',
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'original_source_node_id', type = 'bigint' },
        { column = 'original_target_node_id', type = 'bigint' },
        { column = 'tags', type = 'json' },
        { column = 'geom', type = 'linestring', projection = 4326, not_null = true }
    }
})

function osm2pgsql.process_nodes(object)
    node_tags.insert({ tags = object.tags })
end

function osm2pgsql.process_way(object)
    if isInSet(object.tags['power'], POWER_TAGS) then
        if object.tags['area'] == 'yes' then
            return
        end
        local s = object.nodes[1]
        local t = object.nodes[#object.nodes]  -- last node
        edges:insert({
        original_source_node_id = s,
            original_target_node_id = t,
            tags = object.tags,
            geom = object:as_linestring()
        })
    end
end
