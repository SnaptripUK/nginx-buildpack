local search_id = ngx.var.search_id

ngx.req.set_header("Accept-Encoding", "")					
local search = ngx.location.capture("/searches/" .. search_id .. ".json?" .. ngx.var.QUERY_STRING .. "")

if search.status ~= 200 then
    ngx.status = search.status
	ngx.say("search status ", tostring(search.status))
	ngx.exit(search.status)
else						
    local cjson = require "cjson"
    search_table = cjson.decode(search.body)	
    local property_table = {}
    local property_ids = {}	
	
	-- v[prop][idx] = property
	-- later i can just stream prop
	-- and will end up with 1 => property, which is then ordered!
	
    for i, v in ipairs(search_table["properties"]) do
		property_id = tostring(v["id"])
        property_table[property_id] = v
        property_ids[i] = property_id
    end

    local prices = ngx.location.capture("/prices.json?properties=" .. table.concat(property_ids, ",") .. "&search=" .. search_id .. "")
    prices_table = cjson.decode(prices.body)
    for i, v in ipairs(prices_table) do
        with_prices = property_table[tostring(v["prop_id"])]
	    with_prices["prices"] = v
    end
	
	--make sure to fix _link and filter all meta data out if fields are used!
	local stats = ngx.location.capture("/api/v1/properties/" .. table.concat(property_ids, ";") .. "/stats?fields=score.value,score_b.value")
	stats_table = cjson.decode(stats.body)
	for i, v in ipairs(stats_table["_data"]) do
	    property_id = tostring(v["_data"]["propertyId"])
		with_stats = property_table[property_id]
		with_stats["stats"] = v["_data"]
	end

	-- HOW DO I CONVERT THIS TABLE TO SOMETHING NICER FFS!?
	-- lcal idx = 1
	property_array = {}	
	for i, v in ipairs(property_ids) do
		property_array[i] = property_table[v]
	end
	
	search_table["properties"] = property_array
							
--ngx.header.content_type = 'application/json';
--ngx.say(search.body)	
	
    local zlib = require 'zlib'
    local deflate_stream = zlib.deflate(6, 31)
	
    result_deflated = deflate_stream(cjson.encode(search_table), 'sync')
    ngx.header.content_encoding = 'gzip';
    ngx.header.content_type = 'application/json; charset=utf-8';
    ngx.say(result_deflated)
	
end