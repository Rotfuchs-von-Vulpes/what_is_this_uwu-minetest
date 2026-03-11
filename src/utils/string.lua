local minetest = minetest
local modpath = minetest.get_modpath("what_is_this_uwu")
local compat = dofile(modpath .. "/src/utils/compat.lua")
local compat_cache = {
    get_desc_from_name = {}
}

local M = {}

local DEFAULT_CHAR_WIDTH = 14
local CHAR_WIDTHS = {
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
	_ = 9,
	[" "] = 8,
	["("] = 5,
	[")"] = 5,
	["["] = 5,
	["]"] = 5,
	["1"] = 9,
	["2"] = 9,
	["3"] = 9,
	["4"] = 9,
	["5"] = 9,
	["6"] = 9,
	["7"] = 9,
	["8"] = 9,
	["9"] = 9,
	["0"] = 9,
	["."] = 3,
	[","] = 3,
	["/"] = 8,
	[":"] = 3,
}

function M.string_to_pixels(str)
	local size = 0
	for i = 1, #str do
		local char = str:sub(i, i)
		size = size + (CHAR_WIDTHS[char] or DEFAULT_CHAR_WIDTH)
	end
	return size
end

function M.translate(text, lang)
	if not text or text == "" then
		return ""
	end
	return minetest.get_translated_string(lang, text)
end

function M.collect_lines(desc, mod_name, info)
	local lines = { desc, mod_name }
	if info and info ~= "" then
		for line in info:gmatch("[^\r\n]+") do
			if line:find("progressbar", 1, true) then
				local _, _, progress_line = WhatIsThisApi.parse_string(line)
				line = progress_line
			end
			table.insert(lines, line)
		end
	end
	return lines
end

function M.max_pixel_width(lines)
	local max_size = 0
	for _, text in ipairs(lines) do
		if text and text ~= "" then
			local pixel_size = M.string_to_pixels(text)
			if pixel_size > max_size then
				max_size = pixel_size
			end
		end
	end
	return max_size
end

function M.get_simple_name(name)
	name = name:gsub("_", " ")
	return name:sub(1, 1):upper() .. name:sub(2)
end

function M.get_first_line(text)
	local firstnewline = text:find("\n")
	return firstnewline and text:sub(1, firstnewline - 1) or text
end

function M.get_desc_from_name(node_name, mod_name)
	local wstack = ItemStack(node_name)
	local def = minetest.registered_items[node_name]

	local desc
	if wstack.get_short_description then
		desc = wstack:get_short_description()
	end
	if (not desc or desc == "") and wstack.get_description then
		desc = wstack:get_description()
	end
	if (not desc or desc == "") and not wstack.get_description then
		local meta = wstack:get_meta()
		desc = meta:get_string("description")
	end
	if not desc or desc == "" then
		desc = def.description
	end
	if not desc or desc == "" then
		local drop = def.drop
		local test = M.get_desc_from_name(drop, mod_name)
		desc = test and test or node_name
		desc = node_name
	end
	desc = M.get_first_line(desc)

    if next(compat_cache.get_desc_from_name) == nil then
        for _, value in pairs(compat) do
            if value.string then
                if value.string.get_desc_from_name then
                    table.insert(compat_cache.get_desc_from_name, value.string.get_desc_from_name)
                end
            end
        end
    end

    for _, func in pairs(compat_cache.get_desc_from_name) do
        desc = func(desc, mod_name)
    end

	return desc
end

function M.split_item_name(item_name)
	local colon_pos = item_name:find(":")
	if colon_pos then
		return item_name:sub(1, colon_pos - 1), item_name:sub(colon_pos + 1)
	end
	return item_name, ""
end

return M
