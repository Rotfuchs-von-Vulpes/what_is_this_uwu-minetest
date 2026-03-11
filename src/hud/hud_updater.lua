local minetest = minetest
local get_node = minetest.get_node
local get_player_information = minetest.get_player_information

local M = {}

local utils, classes

function M.init(u, c)
	utils = u
	classes = c
end

-- Translation and info helpers
local function translate_desc(desc, lang)
	return utils.string.translate(desc, lang)
end

local function get_info_text(pos, lang)
	if not pos then
		return ""
	end
	return utils.string.translate(WhatIsThisApi.get_info(pos), lang)
end

local function hud_dimensions(desc, mod_name, pos, hud, lang)
	local desc_t = translate_desc(desc, lang)
	local info = ""
	if not hud.looking_at_mob and pos then
		info = get_info_text(pos, lang)
	end
	local lines = utils.string.collect_lines(desc_t, mod_name, info)
	local size = utils.settings.apply_text_multiplier(utils.string.max_pixel_width(lines)) - 18
	if #hud:get_possible_tools() == 0 then
		size = size - 20
	end
	return size, utils.frame.calculate_hud_height(info)
end

local function update_hud_image(player, hud, form_view, item_type, is_mob)
	local image_id = hud.ids.image
	if is_mob then
		player:hud_change(image_id, "scale", { x = 0.3, y = 0.3 })
		player:hud_change(image_id, "text", "wit_ent.png^[resize:146x146")
	else
		local scale = (item_type ~= "node") and { x = 2.5, y = 2.5 } or { x = 0.3, y = 0.3 }
		player:hud_change(image_id, "scale", scale)
		player:hud_change(image_id, "text", form_view)
	end
end

local function show_hud(player, hud, desc, mod_name, form_view, item_type, pos, was_hidden, is_mob)
	local pname = player:get_player_name()
	local lang = get_player_information(pname).lang_code
	local size, y_size = hud_dimensions(desc, mod_name, pos, hud, lang)
	hud:size(size, y_size, was_hidden)
	player:hud_change(hud.ids.name, "text", desc)
	player:hud_change(hud.ids.mod, "text", mod_name)
	update_hud_image(player, hud, form_view, item_type, is_mob)
end

local function prepare_node_hud(player, form_view, node_name, item_type, pos, hud)
	local was_hidden = hud.pointed_thing == "ignore"
	if was_hidden then
		hud:show()
	end

	if hud.pointed_thing ~= node_name or hud.pointed_thing_pos ~= pos then
		hud:delete_old_lines()
		hud:parse_additional_info(WhatIsThisApi.get_info(pos) or "")
	end

	local str_utils = utils.string
	local mod_name = str_utils.split_item_name(node_name)
	local desc = str_utils.get_desc_from_name(node_name, mod_name)
	desc = utils.settings.apply_technical_name(desc, node_name)

	hud.pointed_thing = node_name
	hud.pointed_thing_pos = pos
	hud.form_view = form_view

	show_hud(player, hud, desc, mod_name, form_view, item_type, pos, was_hidden, false)
end

local function prepare_mob_hud(player, mob_name, mob_type, form_view, item_type, hud)
	local was_hidden = hud.pointed_thing == "ignore"
	if was_hidden then
		hud:show()
	end

	if hud.pointed_thing_pos then
		hud:delete_old_lines()
		hud.pointed_thing_pos = nil
	end

	local str_utils = utils.string
	local mod_name = str_utils.split_item_name(mob_name)
	local desc

	if mob_type == "mob" then
		local name = select(2, str_utils.split_item_name(mob_name))
		mob_name = mob_name:gsub(" %d+$", "")
		desc = str_utils.get_simple_name(name)
	else
		local num = mob_name:match(" (%d+)$")
		desc = str_utils.get_desc_from_name(mob_name, mod_name)
		if num then
			desc = num .. " " .. desc
		end
	end

	desc = utils.settings.apply_technical_name(desc, mob_name)
	hud.pointed_thing = mob_name

	show_hud(player, hud, desc, mod_name, form_view, item_type, nil, was_hidden, mob_type == "mob")
end

function M.update_hud(player, huds, dtime)
	local pname = player:get_player_name()
	local hud = huds[pname]
	if not hud then
		return
	end

	hud:on_step(dtime)
	if hud.hidden then
		hud:hide()
		return
	end

	local pointed_thing, thing_type = utils.entity.get_pointed_thing(player, hud)
	if not pointed_thing then
		hud:hide()
		return
	end

	hud.looking_at_entity = thing_type ~= "node"

	local name, pos
	if thing_type == "node" then
		pos = pointed_thing.under
		name = get_node(pos).name
	else
		name = pointed_thing
	end

	if hud.pointed_thing == name and hud.pointed_thing_pos == pos then
		return
	end

	local form_view, item_type, node_def = utils.entity.get_node_tiles(name, thing_type)
	if not node_def and item_type ~= "mob" then
		hud:hide()
		return
	end

	if thing_type == "node" then
		prepare_node_hud(player, form_view, name, item_type, pos, hud)
		hud:show_possible_tools()
	else
		prepare_mob_hud(player, name, thing_type, form_view, item_type, hud)
		hud:show_possible_tools({ hide = true })
	end
end

return M
