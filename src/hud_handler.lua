local M = { huds = {} }

local function create_new_hud(player)
	local get_vector = M.utils.settings.get_setting_vector
	return M.player_hud.new(player, {
		position = get_vector("position", { x = 0.5, y = 0 }),
		alignment = get_vector("alignment", { x = 0, y = 1 }),
		offset = get_vector("offset", { x = 0, y = 10 }),
	})
end

local function on_join(player)
	M.huds[player:get_player_name()] = create_new_hud(player)
end

local function on_leave(player)
    local name = player:get_player_name()
    if M.huds[name] then
        M.huds[name]:destroy()
        M.huds[name] = nil
    end
end

local function update_all_huds(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		M.what_is_this_uwu.update_hud(player, M.huds, dtime)
	end
end

local function register_command()
	minetest.register_chatcommand("wituwu", {
		params = "",
		description = "Show and unshow the wituwu pop-up",
		privs = {},
		func = function(name)
			local hud = M.huds[name]
			if hud then
				hud.hidden = not hud.hidden
				return true, "Option flipped"
			end
			return false, "HUD not found"
		end,
	})
end

function M.init(modules)
	M.utils = modules.utils
	M.classes = modules.classes
	M.what_is_this_uwu = modules.what_is_this_uwu
	M.player_hud = modules.player_hud

	M.what_is_this_uwu.init(M.utils, M.classes, WhatIsThisApi)
	M.player_hud.init(M.utils, M.classes, WhatIsThisApi)

	minetest.register_on_joinplayer(on_join)
	minetest.register_on_leaveplayer(on_leave)
	minetest.register_globalstep(update_all_huds)
	register_command()
end

return M
