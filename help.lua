local what_is_this_uwu = {
	players = {},
	players_set = {}
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

function what_is_this_uwu.split_item_name(item_name)
	local splited = split(item_name, ':')

	return splited[1], splited[2]
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

function is_strange(str)
	for char in str:gmatch'.' do
		if char == '' then
			return true
		end
	end

	return false
end

function what_is_this_uwu.destrange(str)
	local is_strange = is_strange(str);
	local ignore = true;

	local tem_str
	if is_strange then
		temp_str = str:sub(2, #str-2)
	else
		return str
	end

	str = ''
	temp_str:gsub('.', function(char)
		if not ignore then
			str = str..char
		end

		if char == ')' then
			ignore = false
		end
	end)

	return str
end

function string_to_pixels(str)
	local size = 0

	str:gsub('.', function(char)
		local pixels = char_width[char]

		if pixels then
			size = size + pixels
		else
			size = size + 14
		end
	end)

	return size
end

function inventorycube(img1, img2, img3)
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

function what_is_this_uwu.register_player(player, name)
	if not what_is_this_uwu.players_set[name] then
		table.insert(what_is_this_uwu.players, player)
		what_is_this_uwu.players_set[name] = #what_is_this_uwu.players
	end
end

function what_is_this_uwu.remove_player(name)
	if what_is_this_uwu.players_set[name] then
		table.remove(what_is_this_uwu.players, what_is_this_uwu.players_set[name])
		what_is_this_uwu.players_set[name] = nil
	end
end

function what_is_this_uwu.get_pointed_thing(player)
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

	if not node then
		return 'ignore', 'node', false
	end

	local tiles = node.tiles

	local mod_name, item_name = what_is_this_uwu.split_item_name(node_name)

	if node.inventory_image:sub(1, 14) == '[inventorycube' then

		return node.inventory_image..'^[resize:146x146', 'node', minetest.registered_nodes[node_name]
	elseif node.inventory_image ~= '' then

		return node.inventory_image..'^[resize:16x16', 'craft_item', minetest.registered_nodes[node_name]
	elseif item_name:sub(-2) == '_a' or item_name:sub(-2) == '_b' or item_name:sub(-2) == '_c' then
		local temp = mod_name..':'..item_name:sub(1, -3)
		local tile_temp = minetest.registered_craftitems[temp].inventory_image

		return tile_temp..'^[resize:16x16', 'craft_item', minetest.registered_nodes[node_name]
	else
		if not tiles[1] then
			return '', 'node', minetest.registered_nodes[node_name]
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

		return inventorycube(tiles[1], tiles[6], tiles[3]), 'node', minetest.registered_nodes[node_name]
	end
end

function what_is_this_uwu.show_background(player, meta)
	player:hud_change(
		meta:get_string('wit:background_left'),
		'text',
		'left_side.png'
	)
	player:hud_change(
		meta:get_string('wit:background_middle'),
		'text',
		'middle.png'
	)
	player:hud_change(
		meta:get_string('wit:background_right'),
		'text',
		'right_side.png'
	)
end

function what_is_this_uwu.show(player, meta, form_view, node_description, node_name, item_type, mod_name)
	if meta:get_string('wit:pointed_thing') == 'ignore' then
		what_is_this_uwu.show_background(player, meta)
	end

	meta:set_string('wit:pointed_thing', node_name)

	local size
	if #node_description >= #mod_name then
		size = string_to_pixels(node_description)
	else
		size = string_to_pixels(mod_name)
	end


	player:hud_change(
		meta:get_string('wit:background_middle'),
		'scale',
		{x = size / 16 + 2, y = 2}
	)
	player:hud_change(
		meta:get_string('wit:background_right'),
		'offset',
		{x = size, y = 35}
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
end

return what_is_this_uwu
