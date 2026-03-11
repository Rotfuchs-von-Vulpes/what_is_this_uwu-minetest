WhatIsThisApi = {}
do
	local minetest = minetest

	---Gets the info string from node metadata.
	---@param node_position table Position of the node.
	---@return string Info string or empty string if not found.
	function WhatIsThisApi.get_info(node_position)
		local meta = minetest.get_meta(node_position)
		if not meta then
			return ""
		end

		local info = meta:get_string("what_is_this_info")
		if info == "" then
			info = meta:get_string("infotext")
		end
		return info
	end

	---Sets the info string in node metadata.
	---@param node_position table Position of the node.
	---@param info string Info string to set.
	---@return nil
	function WhatIsThisApi.set_info(node_position, info)
		local meta = minetest.get_meta(node_position)
		if not meta then
			return nil
		end

		meta:set_string("what_is_this_info", info)
	end

	---Parses a progress bar string.
	---@param str string Progress bar string.
	---@return number|nil percent Percentage value.
	---@return string|nil hex Hex color string.
	---@return string|nil text Text inside the progress bar.
	function WhatIsThisApi.parse_string(str)
		str = str:gsub("\n", "")
		local percent = str:match("progressbar%(([%d%.]+)%)")
		local hex = str:match("%((0x%x+)%)")
		local text = str:match("%[(.*)%]$")
		percent = percent and tonumber(percent) or nil
		return percent, hex, text
	end

	---Builds a progress bar string.
	---@param percent number Percentage value.
	---@param hex string Hex color string.
	---@param text string Text inside the progress bar.
	---@return string Progress bar string or empty string if any argument is missing.
	function WhatIsThisApi.get_progress_bar_string(percent, hex, text)
		if not percent or not hex or not text then
			return ""
		end

		return string.format("progressbar(%.1f)(%s)[%s]", percent, hex, text)
	end
end
