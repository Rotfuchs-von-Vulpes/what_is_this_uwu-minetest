local M = {}
M.__index = M

local minetest = minetest
local hud_type_field_name = minetest.features.hud_def_type_field and "type" or "hud_elem_type"
local sign = math.sign

local function get_vec2(tbl, default_x, default_y)
	default_x = default_x or 0
	default_y = default_y or 0
	return { x = (tbl and tbl.x) or default_x, y = (tbl and tbl.y) or default_y }
end

local function hud_add_image(player, position, alignment, offset)
	return player:hud_add({
		[hud_type_field_name] = "image",
		position = position,
		alignment = alignment,
		offset = offset,
	})
end

function M.new(data)
	local self = setmetatable({}, M)

	local player = data.player
	local position = get_vec2(data.position)
	local offset = get_vec2(data.offset)
	local alignment = get_vec2(data.alignment)

	self.scale = { x = 1, y = 1 }
	self.offset = offset
	self.alignment = alignment
	self.player = player
	self.hud_images = self:_init_hud_images(data)
	self.hud = self:_init_hud(player, position, alignment, offset)

	self:change_size(self.scale)
	self:show()

	return self
end

function M:_init_hud_images(data)
	local color = data.color or "#0d23e8"

	return {
		left = data.side .. "^[multiply:" .. color,
		right = data.side .. "^[transform4" .. "^[multiply:" .. color,
		top = data.side .. "^[transform1" .. "^[multiply:" .. color,
		bottom = data.side .. "^[transform3" .. "^[multiply:" .. color,
		bottom_left = data.edge .. "^[transform6" .. "^[multiply:" .. color,
		bottom_right = data.edge .. "^[transform2" .. "^[multiply:" .. color,
		top_left = data.edge .. "^[multiply:" .. color,
		top_right = data.edge .. "^[transform3" .. "^[multiply:" .. color,
		center = data.center,
	}
end

function M:_init_hud(player, position, alignment, offset)
	local function add_image(_alignment, _offset)
		return hud_add_image(player, position, _alignment, _offset or { x = 0, y = 0 })
	end
	return {
		left = add_image({ x = -1 }),
		right = add_image({ x = 1 }),
		top = add_image({ y = 1 }),
		bottom = add_image({ y = -1 }),
		top_left = add_image({ x = -1, y = -1 }),
		top_right = add_image({ x = 1, y = -1 }),
		bottom_right = add_image({ x = 1, y = 1 }),
		bottom_left = add_image({ x = -1, y = 1 }),
		center = add_image(alignment, offset),
	}
end

function M:change_size(scale)
	local player = self.player
	local DEFAULT_OFFSET = 8

	local offset_x = self.offset.x + sign(self.alignment.x) * scale.x * DEFAULT_OFFSET
	local offset_y = self.offset.y + sign(self.alignment.y) * scale.y * DEFAULT_OFFSET

	local x_scale = scale.x * DEFAULT_OFFSET
	local y_scale = scale.y * DEFAULT_OFFSET

	-- Calculate float positions
	local left_x_f = -x_scale + offset_x
	local right_x_f = x_scale + offset_x
	local top_y_f = y_scale + offset_y
	local bottom_y_f = -y_scale + offset_y
	local center_x_f = offset_x
	local center_y_f = offset_y
	local actual_center_x_f = self.offset.x
	local actual_center_y_f = self.offset.y

	-- Round to nearest integer for HUD
	local left_x = math.floor(left_x_f + 0.5)
	local right_x = math.floor(right_x_f + 0.5)
	local top_y = math.floor(top_y_f + 0.5)
	local bottom_y = math.floor(bottom_y_f + 0.5)
	local center_x = math.floor(center_x_f + 0.5)
	local center_y = math.floor(center_y_f + 0.5)
	local actual_center_x = math.floor(actual_center_x_f + 0.5)
	local actual_center_y = math.floor(actual_center_y_f + 0.5)

	-- Calculate the difference caused by rounding
	local left_gap = center_x - left_x
	local right_gap = right_x - center_x
	local top_gap = top_y - center_y
	local bottom_gap = center_y - bottom_y

	-- Ensure touching: if gap > expected, nudge the side piece to close the gap
	local expected_gap_x = x_scale
	local expected_gap_y = y_scale

	if left_gap > expected_gap_x then
		left_x = center_x - expected_gap_x
	end
	if right_gap > expected_gap_x then
		right_x = center_x + expected_gap_x
	end
	if top_gap > expected_gap_y then
		top_y = center_y + expected_gap_y
	end
	if bottom_gap > expected_gap_y then
		bottom_y = center_y - expected_gap_y
	end

	local offsets = {
		left = { x = left_x, y = center_y },
		right = { x = right_x, y = center_y },
		top = { x = center_x, y = top_y },
		bottom = { x = center_x, y = bottom_y },
		top_left = { x = left_x, y = bottom_y },
		top_right = { x = right_x, y = bottom_y },
		bottom_right = { x = right_x, y = top_y },
		bottom_left = { x = left_x, y = top_y },
		center = { x = actual_center_x, y = actual_center_y },
	}

	local scales = {
		left = { x = 1, y = scale.y },
		right = { x = 1, y = scale.y },
		top = { x = scale.x, y = 1 },
		bottom = { x = scale.x, y = 1 },
		top_left = { x = 1, y = 1 },
		top_right = { x = 1, y = 1 },
		bottom_right = { x = 1, y = 1 },
		bottom_left = { x = 1, y = 1 },
		center = { x = scale.x, y = scale.y },
	}

	for name, hud_id in pairs(self.hud) do
		player:hud_change(hud_id, "offset", offsets[name])
		player:hud_change(hud_id, "scale", scales[name])
	end

	self.scale = scale
end

function M:hide()
	for _, elem in pairs(self.hud) do
		self.player:hud_change(elem, "text", "")
	end
end

function M:show()
	for name, elem in pairs(self.hud) do
		self.player:hud_change(elem, "text", self.hud_images[name])
	end
end

function M:destroy()
    for _, id in pairs(self.hud) do
        if self.player and self.player:is_player() then
            self.player:hud_remove(id)
        end
    end
end

return M
