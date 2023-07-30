local what_is_this_uwu = {
	players = {},
	players_set = {},
	prev_tool = {}
}

local function split (str, sep)
	if sep == nil then
		sep = "%s"
	end

	local t = {}
	for char in string.gmatch(str, "([^"..sep.."]+)") do
		table.insert(t, char)
	end

	return t
end

local char_width = {
	A = 12,
	B = 10,
	C = 13,
	D = 12,
	E = 11,
	F = 9,
	G = 13,
	H = 12,
	I = 3,
	J = 9,
	K = 11,
	L = 9,
	M = 13,
	N = 11,
	O = 13,
	P = 10,
	Q = 13,
	R = 12,
	S = 10,
	T = 11,
	U = 11,
	V = 10,
	W = 15,
	X = 11,
	Y = 11,
	Z = 10,
	a = 10,
	b = 8,
	c = 8,
	d = 9,
	e = 9,
	f = 5,
	g = 9,
	h = 9,
	i = 2,
	j = 6,
	k = 8,
	l = 4,
	m = 13,
	n = 8,
	o = 10,
	p = 8,
	q = 10,
	r = 4,
	s = 8,
	t = 5,
	u = 8,
	v = 8,
	w = 12,
	x = 8,
	y = 8,
	z = 8,
}
char_width[' '] = 5
char_width['_'] = 9

local function is_strange(str)
	for char in str:gmatch'.' do
		if char == '' then
			return true
		end
	end

	return false
end

local function string_to_pixels(str)
	local size = 0

	for char in str:gmatch"." do
		local pixels = char_width[char]

		if pixels then
			size = size + pixels
		else
			size = size + 14
		end
	end

	return size
end

local function inventorycube(img1, img2, img3)
	if not img1 then return '' end

	img2 = img2 or img1
	img3 = img3 or img1

	img1 = img1..'^[resize:16x16'
	img2 = img2..'^[resize:16x16'
	img3 = img3..'^[resize:16x16'

	return "[inventorycube"..
		"{"..img1:gsub("%^","&")..
		"{"..img2:gsub("%^","&")..
		"{"..img3:gsub("%^","&")
end

local function serialize(val, name, skipnewlines, depth)
	skipnewlines = skipnewlines or false
	depth = depth or 0

	local tmp = string.rep(' ', depth)

	if name then tmp = tmp .. name .. ' = ' end

	if type(val) == 'table' then
		tmp = tmp .. '{' .. (not skipnewlines and '\n' or '')

		for k, v in pairs(val) do
			tmp =  tmp .. serialize(v, k, skipnewlines, depth + 1) .. ',' .. (not skipnewlines and '\n' or '')
		end

		tmp = tmp .. string.rep(' ', depth) .. '}'
	elseif type(val) == 'number' then
		tmp = tmp .. tostring(val)
	elseif type(val) == 'string' then
		tmp = tmp .. string.format('%q', val)
	elseif type(val) == 'boolean' then
		tmp = tmp .. (val and 'true' or 'false')
	else
		tmp = tmp .. '\'[inserializeable datatype:' .. type(val) .. ']\''
	end

	return tmp
end

function what_is_this_uwu.split_item_name(item_name)
	local splited = split(item_name, ':')

	return splited[1], splited[2]
end

function what_is_this_uwu.destrange(str)
	local is_strange = is_strange(str);
	local ignore = true;

	local temp_str
	if is_strange then
		local temp_str = ''
		local reading = true
		local is_special = false
		local between_parenthesis = false
		
		for char in str:gmatch'.' do
			if char == '' then
				reading = false
			elseif reading and not between_parenthesis then
				temp_str = temp_str..char
			else
				reading = true
			end

			if between_parenthesis then
				if char == ')' then
					between_parenthesis = false
				end
			else
				if char == '(' then
					between_parenthesis = true
				end
			end
		end

		return temp_str
	else
		return str
	end
end

function what_is_this_uwu.register_player(player, name)
	if not what_is_this_uwu.players_set[name] then
		table.insert(what_is_this_uwu.players, player)
		what_is_this_uwu.players_set[name] = true 
	end
end

function what_is_this_uwu.remove_player(name)
	if what_is_this_uwu.players_set[name] then
		what_is_this_uwu.players_set[name] = false

		for i, player in ipairs(what_is_this_uwu.players) do
			if player == name then
				table.remove(what_is_this_uwu.players, i)
				break
			end
		end
	end
end

function what_is_this_uwu.get_pointed_thing(player)
	if not what_is_this_uwu.players_set[player:get_player_name()] then return end

	-- get player position
	local player_pos = player:get_pos()
	local eye_height = player:get_properties().eye_height
	local eye_offset = player:get_eye_offset()
	player_pos.y = player_pos.y + eye_height
	player_pos = vector.add(player_pos, eye_offset)

	-- set liquids vision
	local see_liquid = 
		minetest.registered_nodes[minetest.get_node(player_pos).name].drawtype ~= 'liquid'

	-- get wielded item range 5 is engine default
	-- order tool/item range >> hand_range >> fallback 5
	local tool_range = player:get_wielded_item():get_definition().range or nil					
	local hand_range	
		for key, val in pairs(minetest.registered_items) do								
			if key == "" then
				hand_range = val.range or nil
			end
		end
	local wield_range = tool_range or hand_range or 5

	-- determine ray end position
	local look_dir = player:get_look_dir()
	look_dir = vector.multiply(look_dir, wield_range)
	local end_pos = vector.add(look_dir, player_pos)

	-- get pointed_thing
	local ray = minetest.raycast(player_pos, end_pos, false, see_liquid)

	return ray:next()
end

function what_is_this_uwu.get_node_tiles(node_name)
	local node = minetest.registered_nodes[node_name]
	local node_definition = node

	if not node then
		return 'ignore', 'node', false
	end

	if node.groups['not_in_creative_inventory'] then
		drop = node.drop
		if drop and type(drop) == 'string' then
			node_name = drop
			node = minetest.registered_nodes[drop]
			if not node then 
				node = minetest.registered_craftitems[drop]
			end
		end
	end

	if not node or (not node.tiles and not node.inventory_image) then
		return 'ignore', 'node', false
	end

	local tiles = node.tiles

	local mod_name, item_name = what_is_this_uwu.split_item_name(node_name)

	if node.inventory_image:sub(1, 14) == '[inventorycube' then
		return node.inventory_image..'^[resize:146x146', 'node', node_definition
	elseif node.inventory_image ~= '' then
		return node.inventory_image..'^[resize:16x16', 'craft_item', node_definition
	else
		if not tiles[1] then
			return '', 'node', node_definition
		end

		tiles[3] = tiles[3] or tiles[1]
		tiles[6] = tiles[6] or tiles[3]

		if type(tiles[1]) == 'table' then
			tiles[1] = tiles[1].name
		end
		if type(tiles[3]) == 'table' then
			tiles[3] = tiles[3].name
		end
		if type(tiles[6]) == 'table' then
			tiles[6] = tiles[6].name
		end

		return inventorycube(tiles[1], tiles[6], tiles[3]), 'node', node_definition
	end
end

function what_is_this_uwu.show_background(player, meta)
	player:hud_change(
		meta:get_string('wit:background_left'),
		'text',
		'wit_left_side.png'
	)
	player:hud_change(
		meta:get_string('wit:background_middle'),
		'text',
		'wit_middle.png'
	)
	player:hud_change(
		meta:get_string('wit:background_right'),
		'text',
		'wit_right_side.png'
	)
end

function what_is_this_uwu.show(player, meta, form_view, node_description, node_name, item_type, mod_name)
	if meta:get_string('wit:pointed_thing') == 'ignore' then
		what_is_this_uwu.show_background(player, meta)
	end

	meta:set_string('wit:pointed_thing', node_name)

	if minetest.registered_items[node_name]._tt_original_description then
		node_description = what_is_this_uwu.destrange(minetest.registered_items[node_name]._tt_original_description)
	end
	
	local size
	if #node_description >= #mod_name then
		size = string_to_pixels(node_description)
	else
		size = string_to_pixels(mod_name)
	end

	size = size - 18

	player:hud_change(
		meta:get_string('wit:background_middle'),
		'scale',
		{x = size / 16 + 1.5, y = 2}
	)

	player:hud_change(
		meta:get_string('wit:background_middle'),
		'offset',
		{x = -size / 2 - 9.5, y = 35}
	)

	player:hud_change(
		meta:get_string('wit:background_right'),
		'offset',
		{x = size / 2 + 30, y = 35}
	)
	player:hud_change(
		meta:get_string('wit:background_left'),
		'offset',
		{x = -size / 2 - 25, y = 35}
	)

	player:hud_change(
		meta:get_string('wit:image'),
		'offset',
		{x = -size / 2 - 12.5, y = 35}
	)
	player:hud_change(
		meta:get_string('wit:name'),
		'offset',
		{x = -size / 2 + 16.5, y = 22}
	)
	player:hud_change(
		meta:get_string('wit:mod'),
		'offset',
		{x = -size / 2 + 16.5, y = 37}
	)
	player:hud_change(
		meta:get_string('wit:best_tool'),
		'offset',
		{x = -size / 2 + 16.5, y = 51}
	)
	player:hud_change(
		meta:get_string('wit:tool_in_hand'),
		'offset',
		{x = -size / 2 + 16.5, y = 51}
	)

	local item_def = minetest.registered_items[node_name]
	local groups = item_def.groups
	
	local group_index = -1
	local index_to_image = {"wit_hand.png", "wit_spade.png", "wit_pickaxe.png", "wit_hand.png", "wit_axe.png", "wit_sword.png", "wit_hand.png"}
	
	for index, group in ipairs({"dig_immediate", "crumbly", "cracky", "snappy", "choppy", "fleshy", "explody"}) do
		if groups[group] then
			group_index = index
			break
		end
	end
	
	local best_to_mine = index_to_image[group_index] or "wit_hand.png"
	
	local wielded_item = player:get_wielded_item()
	local item_name = wielded_item:get_name()
	
	local tool_groups = {"pickaxe", "shovel", "sword", "axe"}
	local correct_tool_in_hand = false
	local any_tool_in_hand = false

	local liquids = {"default:water_source", "default:river_water_source", "default:lava_source",}
	if table.concat(liquids, ","):find(node_name) then
		best_to_mine = "wit_bucket.png"
		if item_name == "bucket:bucket_empty" then
			correct_tool_in_hand = true
		else
			correct_tool_in_hand = false
		end
	else
		for _, tool_group in ipairs(tool_groups) do
			if minetest.get_item_group(item_name, tool_group) > 0 then
				any_tool_in_hand = true
				if (tool_group == "pickaxe" and group_index == 3) or
				   (tool_group == "shovel" and group_index == 2) or
				   (tool_group == "sword" and group_index == 6) or
				   (tool_group == "axe" and group_index == 5) then
					correct_tool_in_hand = true
					break
				end
			end
		end
	
		if not any_tool_in_hand and (group_index ~= 3 and group_index ~= 2 and group_index ~= 6 and group_index ~= 5) then
			correct_tool_in_hand = true
		end
	end
	
	local correct_tool_image = correct_tool_in_hand and "wit_checkmark.png" or "wit_nope.png"

	player:hud_change(
		meta:get_string('wit:best_tool'),
		'text',
		best_to_mine
	)
	player:hud_change(
		meta:get_string('wit:tool_in_hand'),
		'text',
		correct_tool_image
	)
	player:hud_change(
		meta:get_string('wit:image'),
		'text',
		form_view
	)

	player:hud_change(
		meta:get_string('wit:name'),
		'text',
		node_description
	)
	player:hud_change(
		meta:get_string('wit:mod'),
		'text',
		mod_name
	)

	if meta:get_string('wit:item_type_in_pointer') ~= item_type then
		local scale = {}

		meta:set_string('wit:item_type_in_pointer', item_type)

		if item_type == 'node' then
			scale.x = 0.3
			scale.y = 0.3
		else
			scale.x = 2.5
			scale.y = 2.5
		end

		player:hud_change(
			meta:get_string('wit:image'),
			'scale',
			scale
		)
	end
end

function what_is_this_uwu.unshow(player, meta)
	if not meta then return end

	meta:set_string('wit:pointed_thing', 'ignore')

	player:hud_change(
		meta:get_string('wit:background_left'),
		'text',
		''
	)
	player:hud_change(
		meta:get_string('wit:background_middle'),
		'text',
		''
	)
	player:hud_change(
		meta:get_string('wit:background_right'),
		'text',
		''
	)

	player:hud_change(
		meta:get_string('wit:image'),
		'text',
		''
	)
	player:hud_change(
		meta:get_string('wit:name'),
		'text',
		''
	)
	player:hud_change(
		meta:get_string('wit:mod'),
		'text',
		''
	)
	player:hud_change(
		meta:get_string('wit:best_tool'),
		'text',
		''
	)
	player:hud_change(
		meta:get_string('wit:tool_in_hand'),
		'text',
		''
	)
end

return what_is_this_uwu
