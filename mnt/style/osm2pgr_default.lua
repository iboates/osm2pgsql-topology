-- Numeric values are from https://github.com/pgRouting/osm2pgrouting/blob/main/mapconfig.xml
HIGHWAY_TAGS = {
    road = 100,
    motorway = 101,
    motorway_link = 102,
    motorway_junction = 103,
    trunk = 104,
    trunk_link = 105,
    primary = 106,
    primary_link = 107,
    secondary = 108,
    secondary_link = 124,
    tertiary = 109,
    tertiary_link = 125,
    residential = 110,
    living_street = 111,
    service = 112,
    track = 113,
    pedestrian = 114,
    services = 115,
    bus_guideway = 116,
    path = 117,
    cycleway = 118,
    footway = 119,
    bridleway = 120,
    byway = 121,
    steps = 122,
    unclassified = 123
}

CYCLEWAY_TAGS = {
    lane = 201,
    track = 202,
    opposite_lane = 203,
    opposite = 204
}

TRACKTYPE_TAGS = {
   grade1 = 301,
   grade2 = 302,
   grade3 = 303,
   grade4 = 304,
   grade5 = 305
}

JUNCTION_TAGS = {
   roundabout = 401
}

function parseAndRound(str)
    local num = tonumber(str)
    if num then
        return math.floor(num + 0.5)
    else
        return -9999
    end
end

function parseOneWay(str)
    if type(str) ~= "string" then
        return "UNKNOWN"
    end

    local lowerStr = string.lower(str)

    if lowerStr == "yes" then
        return "YES"
    elseif lowerStr == "no" then
        return "NO"
    elseif lowerStr == "reversed" then
        return "REVERSED"
    else
        return "UNKNOWN"
    end
end

function parseOneWayToInteger(str)
    if type(str) ~= "string" then
        return 0
    end

    local lowerStr = string.lower(str)

    if lowerStr == "yes" then
        return 1
    elseif lowerStr == "no" then
        return 2
    elseif lowerStr == "reversed" then
        return -1
    else
        return 0
    end
end

-- function isInSet(value, set)
--     for _, v in ipairs(set) do
--         if v == value then
--             return true
--         end
--     end
--     return false
-- end

function isInSet(value, set)
    return set[value] ~= nil
end

function handleMaxSpeed(tags)
    if tags["maxspeed"] ~= nil then
        return {
            maxspeed_forward = parseAndRound(tags["maxspeed"]),
            maxspeed_backward = parseAndRound(tags["maxspeed"])
        }
    end
    out = {
        maxspeed_forward = 50,
        maxspeed_backward = 50
    }
    if tags["maxspeed:forward"] ~= nil then
        out["maxspeed_forward"] = parseAndRound(tags["maxspeed:forward"])
    end
    if tags["maxspeed:backward"] ~= nil then
        out["maxspeed_backward"] = parseAndRound(tags["maxspeed:backward"])
    end
    return out
end

local node_tags = osm2pgsql.define_table({
    name = 'node_tags',
    ids = { type = 'any', id_column = 'osm_id' },
    columns = {
        { column = 'junction', type = 'text' },
    }
})

local edges = osm2pgsql.define_table({
    name = 'edges_pre',
    ids = { type = 'any', id_column = 'osm_id' },
    columns = {
        { column = 'tag_id', type = 'integer' },
        { column = 'name', type = 'text' },
        { column = 'original_source_node_id', type = 'bigint' },
        { column = 'original_target_node_id', type = 'bigint' },
        { column = 'one_way', type = 'integer' },
        { column = 'oneway', type = 'text' },
        { column = 'maxspeed_forward', type = 'integer' },
        { column = 'maxspeed_backward', type = 'integer' },
        { column = 'priority', type = 'integer' },
        { column = 'tags', type = 'json' },
        { column = 'geom', type = 'linestring', projection = 4326, not_null = true },
    }
})

function osm2pgsql.process_nodes(object)
    node_tags.insert({ junction = object.tags.junction })
end

function osm2pgsql.process_way(object)

    if isInSet(object.tags['highway'], HIGHWAY_TAGS) then
        local tag_id = HIGHWAY_TAGS[object.tags['highway']]
    elseif isInSet(object.tags['cycleway'], CYCLEWAY_TAGS) then
        local tag_id = CYCLEWAY_TAGS[object.tags['cycleway']]
    elseif isInSet(object.tags['tracktype'], CYCLEWAY_TAGS) then
        local tag_id = TRACKTYPE_TAGS[object.tags['tracktype']]
    else
        return
    end
        
    local source = object.nodes[1]
    local target = object.nodes[#object.nodes]  -- last node
    local maxspeed = handleMaxSpeed(object.tags)
    local one_way = parseOneWayToInteger(object.tags['oneway'])
    local oneway = parseOneWay(object.tags['oneway'])

    edges:insert({
        tag_id = tag_id,
        name = object.tags['name'],
        original_source_node_id = source,
        original_target_node_id = target,
        one_way = one_way,
        oneway = oneway,
        maxspeed_forward = maxspeed.maxspeed_forward,
        maxspeed_backward = maxspeed.maxspeed_backward,
        priority = 0,
        tags = object.tags,
        geom = object:as_linestring()
    })

end
