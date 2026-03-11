local M = {}
M.__index = M

-- Cache globals
local pairs, ipairs, type, tonumber = pairs, ipairs, type, tonumber
local table_insert = table.insert
local math_sign = math.sign

local hud_type_field_name = minetest.features.hud_def_type_field and "type" or "hud_elem_type"

local DEFAULT_OFFSET = 8
local LIQUIDS_SET = {
	["default:water_source"] = true,
	["default:river_water_source"] = true,
	["default:lava_source"] = true,
}

function M.init(utils, classes, api)
	M.utils = utils
	M.classes = classes
	M.api = api
end

-- HUD element creation helpers
local function create_hud_image(player, position)
	return player:hud_add({
		[hud_type_field_name] = "image",
		position = position,
		alignment = { x = 1 },
		scale = { x = 0.3, y = 0.3 },
	})
end

local function create_hud_text(player, position, color, style)
	return player:hud_add({
		[hud_type_field_name] = "text",
		position = position,
		scale = { x = 0.3, y = 0.3 },
		number = color,
		alignment = { x = 1 },
		style = style,
	})
end

local function create_hud_tool_image(player, position)
	return player:hud_add({
		[hud_type_field_name] = "image",
		position = position,
		scale = { x = 1, y = 1 },
		alignment = { x = 1, y = 1 },
	})
end

function M.new(player, data)
	local self = setmetatable({}, M)
	data = data or {}

	local get_vec2 = M.utils.vector.get_vec2
	local settings = M.utils.settings

	self.alignment = get_vec2(data.alignment, 0, 1)
	self.position = get_vec2(data.position, 0.5, 0)
	self.offset = get_vec2(data.offset, 0, 10)
	self.player = player
	self.hidden = false
	self.shown_on_screen = true
	self.pointed_thing = "ignore"
	self.pointed_thing_pos = nil
	self.lines = {}
	self.previous_infotext = ""
	self.size_of = { x = 0, y = 0 }
	self.possible_tools = {}
	self.possible_tool_index = 1

    self.ids = {
        frame = self:create_frame(),
        image = create_hud_image(player, self.position),
        name = create_hud_text(player, self.position, 0xffffff),
        mod = create_hud_text(player, self.position, 0xff3c0a, 2),
        best_tool = create_hud_tool_image(player, self.position),
        tool_in_hand = create_hud_tool_image(player, self.position)
    }

	local period = tonumber(minetest.settings:get("what_is_this_uwu_rate_of_change")) or 1.0
	self.timer = M.classes.timer.new(period, function()
		self:on_timer()
	end)

	if settings.get_bool("spring") then
		local spring_frequency = settings.get_setting_or("spring_frequency", 5)
		local spring_class = M.classes.spring
		self.scale = {
			x = spring_class.new(0.8, spring_frequency, self.ids.frame.scale.x),
			y = spring_class.new(0.8, spring_frequency, self.ids.frame.scale.y),
		}
	end

	return self
end

function M:on_timer()
	local tools = self.possible_tools
	local count = #tools
	if count == 0 then
		return
	end
	self.possible_tool_index = (self.possible_tool_index % count) + 1
	self:show_possible_tools()
end

function M:create_frame()
	return M.classes.frame.new({
		side = "wit_side.png",
		center = "wit_center.png",
		edge = "wit_edge.png",
		position = self.position,
		alignment = self.alignment,
		offset = self.offset,
		player = self.player,
		color = M.utils.settings.get_setting_or("frame_color", "#0d23e8"),
	})
end

function M:size(size, y_size, previously_hidden)
	local player, frame = self.player, self.ids.frame
	local alignment, offset = self.alignment, self.offset

	local x_scale = (size / 16 + 6) * DEFAULT_OFFSET
	local y_scale = y_size * DEFAULT_OFFSET

	self.size_of.x = x_scale
	self.size_of.y = y_scale

	local align_x_sign = math_sign(alignment.x)
	local align_y_sign = math_sign(alignment.y)
	local offset_x = offset.x + align_x_sign * x_scale
	local offset_y = offset.y + align_y_sign * y_scale

	local left_x = -x_scale + offset_x
	local right_x = x_scale + offset_x
	local bottom_y = -y_scale + offset_y

	player:hud_change(self.ids.image, "offset", { x = left_x + 2, y = offset_y })
	player:hud_change(self.ids.name, "offset", { x = left_x + 48, y = bottom_y + 13 })

	local tool_x = right_x - 17
	local tool_y = bottom_y + 1
	player:hud_change(self.ids.best_tool, "offset", { x = tool_x, y = tool_y })
	player:hud_change(self.ids.tool_in_hand, "offset", { x = tool_x, y = tool_y })
	self:position_additional_info_lines()

	local final_x = x_scale / DEFAULT_OFFSET
	local final_y = y_scale / DEFAULT_OFFSET
	local scale = self.scale

	if not scale then
		frame:change_size({ x = final_x, y = final_y })
		return
	end

	if previously_hidden then
		frame:change_size({ x = final_x, y = final_y })
		scale.x:setGoal(final_x)
		scale.y:setGoal(y_size)
		scale.x:step(100000)
		scale.y:step(100000)
		return
	end

	scale.x:setGoal(final_x)
	scale.y:setGoal(final_y)
end

-- Line management
function M:create_line(data)
	local is_progress_bar = data.progress_bar or false
	local text = data.text or ""
	local percent = tonumber(data.percent) or 0
	local hex = data.hex or "0xffffff"
	local player = self.player
	local position = self.position
	local lines = self.lines

	if is_progress_bar then
		local hex_color = hex:sub(3)
		table_insert(lines, {
			type = "progress_bar",
			percent = percent,
			behind_bar = player:hud_add({
				[hud_type_field_name] = "image",
				position = position,
				scale = { x = 1, y = 1 },
				alignment = { x = 1 },
				text = "wit_progress_bar.png^[multiply:#3d373c",
			}),
			bar = player:hud_add({
				[hud_type_field_name] = "image",
				position = position,
				scale = { x = 1, y = 1 },
				alignment = { x = 1 },
				text = "wit_progress_bar.png^[multiply:#" .. hex_color,
			}),
			bar_text = player:hud_add({
				[hud_type_field_name] = "text",
				position = position,
				number = 0xffffff,
				scale = { x = 1, y = 1 },
				alignment = { x = 1 },
				text = text,
			}),
		})
		return
	end

	table_insert(lines, {
		type = "text",
		line_text = player:hud_add({
			[hud_type_field_name] = "text",
			number = 0xc4c4c4,
			position = position,
			scale = { x = 1, y = 1 },
			alignment = { x = 1 },
			text = text,
		}),
	})
end

function M:delete_old_lines()
	local player, lines = self.player, self.lines
	if not lines or not player then
		return
	end
	for i = #lines, 1, -1 do
		local elem = lines[i]
		if elem.type == "text" then
			player:hud_remove(elem.line_text)
		else
			player:hud_remove(elem.behind_bar)
			player:hud_remove(elem.bar)
			player:hud_remove(elem.bar_text)
		end
		lines[i] = nil
	end
end

function M:parse_additional_info(text)
	self:delete_old_lines()
	if not text or text == "" then
		return
	end
	for line in text:gmatch("[^\n]+") do
		if line:find("progressbar", 1, true) then
			local percent, hex, bar_text = WhatIsThisApi.parse_string(line)
			if percent and hex then
				self:create_line({
					progress_bar = true,
					text = bar_text,
					hex = hex,
					percent = percent,
				})
			end
		else
			self:create_line({
				progress_bar = false,
				text = line,
			})
		end
	end
	self:position_additional_info_lines()
end

function M:handle_spring(dt)
	local scale = self.scale
	if not scale then
		return
	end
	scale.x:step(dt)
	scale.y:step(dt)
	self.ids.frame:change_size({
		x = scale.x:getPosition(),
		y = scale.y:getPosition(),
	})
end

function M:on_step(dt)
	self.timer:on_step(dt)
	if self.shown_on_screen and self.pointed_thing_pos then
		self:set_additional_info(self.pointed_thing_pos)
	end
	self:handle_spring(dt)
end

function M:position_additional_info_lines()
	local player, lines = self.player, self.lines
	local y_step = 18
	local alignment, offset, size_of = self.alignment, self.offset, self.size_of

	local x_scale, y_scale = size_of.x, size_of.y
	local offset_x = offset.x + math_sign(alignment.x) * x_scale
	local offset_y = offset.y + math_sign(alignment.y) * y_scale

	local left_x = -x_scale + offset_x
	local top_y = y_scale + offset_y
	local bottom_y = -y_scale + offset_y
	local base_x = left_x + 48
	local base_y = bottom_y + 29

	for i, line in ipairs(lines) do
		local x = base_x
		local y = base_y + (i - 1) * y_step
		if line.type == "text" and line.line_text then
			player:hud_change(line.line_text, "offset", { x = x, y = y })
		elseif line.type == "progress_bar" then
			local line_scale_x = (x_scale / DEFAULT_OFFSET) - 3.4
			if line.behind_bar then
				player:hud_change(line.behind_bar, "offset", { x = x, y = y })
				player:hud_change(line.behind_bar, "scale", { x = line_scale_x, y = 1 })
			end
			if line.bar then
				player:hud_change(line.bar, "offset", { x = x, y = y })
				player:hud_change(line.bar, "scale", { x = line_scale_x * (line.percent / 100), y = 1 })
			end
			if line.bar_text then
				player:hud_change(line.bar_text, "offset", { x = x, y = y - 1 })
			end
		end
	end

	local mod_offset_y = #lines == 0 and -10 or 0
	player:hud_change(self.ids.mod, "offset", { x = base_x, y = top_y - 10 + mod_offset_y })
end

function M:set_additional_info(pos)
	local info = WhatIsThisApi.get_info(pos)
	if self.previous_infotext ~= info then
		self:parse_additional_info(info or "")
	end
	self.previous_infotext = info or ""
end

function M:hide()
	local player = self.player
	for _, element in pairs(self.ids) do
		if type(element) == "number" then
			player:hud_change(element, "text", "")
		end
	end

	self.pointed_thing = "ignore"
	self.pointed_thing_pos = nil
	self.ids.frame:hide()
	self.shown_on_screen = false
	self:delete_old_lines()
end

function M:show()
	self.ids.frame:show()
	self.shown_on_screen = true
end

function M:get_possible_tools()
	local node_name = self.pointed_thing
	local item_def = minetest.registered_items[node_name]
	local groups = item_def and item_def.groups or {}
	local player = self.player
	local possible_tools = {}
	local registered_tools = minetest.registered_tools

	for toolname, tooldef in pairs(registered_tools) do
		local caps = tooldef.tool_capabilities and tooldef.tool_capabilities.groupcaps
		if caps then
			for group in pairs(groups) do
				if caps[group] then
					table_insert(possible_tools, toolname)
					break
				end
			end
		end
	end

	local wielded_item = player:get_wielded_item()
	local item_name = wielded_item:get_name()
	local correct_tool_in_hand = false

	if LIQUIDS_SET[node_name] then
		possible_tools = { "bucket:bucket_empty" }
		correct_tool_in_hand = (item_name == "bucket:bucket_empty")
	else
		for _, tool in ipairs(possible_tools) do
			if item_name == tool then
				correct_tool_in_hand = true
				break
			end
		end
	end

	return possible_tools, correct_tool_in_hand
end

function M:show_possible_tools(options)
	local player = self.player
	local pointed_thing = self.pointed_thing

	if
		(options and options.hide)
		or not self.form_view
		or self.form_view == ""
		or not pointed_thing
		or pointed_thing == ""
		or pointed_thing == "ignore"
	then
		player:hud_change(self.ids.best_tool, "text", "")
		player:hud_change(self.ids.tool_in_hand, "text", "")
		return
	end

	local possible_tools, correct_tool_in_hand = self:get_possible_tools()
	self.possible_tools = possible_tools

	local tool = possible_tools[self.possible_tool_index] or possible_tools[1]
	local texture = ""

	if tool then
		local tool_def = minetest.registered_tools[tool] or minetest.registered_craftitems[tool]
		texture = tool_def and tool_def.inventory_image or ""
	end

	if texture ~= "" then
		texture = texture .. "^[resize:16x16"
	end

	player:hud_change(self.ids.best_tool, "text", texture)

	local correct_tool_texture = ""
	if texture ~= "" then
		correct_tool_texture = correct_tool_in_hand and "wit_checkmark.png" or "wit_nope.png"
	end
	player:hud_change(self.ids.tool_in_hand, "text", correct_tool_texture)
end

function M:destroy()
    local player = self.player
    if not player or not player:is_player() then return end

    for _, id in pairs(self.ids) do
        player:hud_remove(id)
    end

    self:delete_old_lines()

    if self.ids.frame and self.ids.frame.destroy then
        self.ids.frame:destroy()
    end
end

return M
