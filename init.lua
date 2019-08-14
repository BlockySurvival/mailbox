--[[ Old mailbox.lua from kilbith's excellent X-Decor mod
     https://github.com/minetest-mods/xdecor
     GPL3 ]]

mailbox = {}
screwdriver = screwdriver or {}

local storage = minetest.get_mod_storage()
local modpath = minetest.get_modpath('mailbox')
assert(loadfile(modpath .. '/global_storage.lua'))(storage)

function mailbox.get_formspec(pos, owner, fs_type)
	local selected = "false"
	if minetest.get_node(pos).name == "mailbox:letterbox" then
		selected = "true"
	end
	local xbg = default.gui_bg .. default.gui_bg_img .. default.gui_slots
	local spos = pos.x .. "," ..pos.y .. "," .. pos.z

	if fs_type == 1 then
		local meta = minetest.get_meta(pos)
		local global_storage = meta:get_string("storage_method") == "player"
		local fs = "size[8,9.5]" .. xbg .. default.get_hotbar_bg(0, 5.5) ..
			"checkbox[0,-0.25;books_only;Only allow written books;" .. selected ..
				"]" ..
			"checkbox[0,0.25;global_storage;Use global storage (\"ender che" ..
				"st\" mode);" .. (global_storage and "true" or "false") .. "]"

		if not global_storage then
			fs = fs ..
				"list[nodemeta:" .. spos .. ";mailbox;0,1;8,4;]" ..
				"listring[nodemeta:" .. spos .. ";mailbox]"
		elseif minetest.get_player_by_name(owner) then
			fs = fs ..
				"list[current_player;mailbox;0,1;8,4;]" ..
				"listring[current_player;mailbox]"
		else
			fs = fs ..
				"label[0,1;You cannot access mailbox contents while cloaked.]"
		end

		return fs ..
			"list[current_player;main;0,5.5;8,1;]" ..
			"list[current_player;main;0,6.75;8,3;8]" ..
			"listring[current_player;main]" ..
			"button_exit[6,0;1,1;unrent;Unrent]"..
			"button_exit[7,0;1,1;exit;X]"
	else
		return "size[8,5.5]" .. xbg .. default.get_hotbar_bg(0, 1.5) ..
			"label[0,0;Send your goods\nto " .. owner .. " :]" ..
			"list[nodemeta:" .. spos .. ";drop;3.5,0;1,1;]" ..
			"list[current_player;main;0,1.5;8,1;]" ..
			"list[current_player;main;0,2.75;8,3;8]" ..
			"listring[nodemeta:" .. spos .. ";drop]" ..
			"listring[current_player;main]"
	end
end

function mailbox.unrent(pos, player)
   local meta = minetest.get_meta(pos)
   local node = minetest.get_node(pos)
   node.name = "mailbox:mailbox_free"
   minetest.swap_node(pos, node) -- preserve Facedir
   --   minetest.swap_node(pos, {name = "mailbox:mailbox" })
   meta:set_string("storage_method", "")
   mailbox.after_place_free(pos, player)
end

-- function mailbox.get_free_formspec(pos, player, owner)
--    local xbg = default.gui_bg .. default.gui_bg_img .. default.gui_slots
-- 	--	local spos = pos.x .. "," ..pos.y .. "," .. pos.z
--    fsp="size[5,3]"..xbg
--    if owner and player == owner then
--       "" -- text field to enter starting letters
--       fspec=fspec.."field[2,0.5;4,1;name;Restrict usernames;default]"
--    end
--    -- Button to rent
-- end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, 16) ~= "mailbox:mailbox_" then return end

	-- Validate the position
	local pos = minetest.string_to_pos(formname:sub(17))
	if not pos then return end

	-- Validate the node
	local node = minetest.get_node(pos)
	local pname = player:get_player_name()
	if node.name ~= "mailbox:mailbox" and node.name ~= "mailbox:letterbox" then
		minetest.chat_send_player(pname, "The mailbox you tried to interact" ..
			" with has been removed!")
		minetest.close_formspec(pname, formname)
		return
	end

	-- Validate the owner
	local meta = minetest.get_meta(pos)
	if meta:get_string("owner") ~= pname then
		-- This should never happen, maybe this should crash the client.
		minetest.chat_send_player(pname,
			"That's not your mailbox to mess with!")
		minetest.close_formspec(pname, formname)
		return
	end

	-- Now do the actual things
	if fields.unrent then
		local inv = meta:get_inventory()
		if inv:is_empty("mailbox") then
			mailbox.unrent(pos, player)
		else
			minetest.chat_send_player(pname, "Your mailbox is not empty!")
		end
	end

	if fields.books_only then
		if node.name == "mailbox:mailbox" then
			node.name = "mailbox:letterbox"
			minetest.swap_node(pos, node)
		else
			node.name = "mailbox:mailbox"
			minetest.swap_node(pos, node)
		end
	end

	if fields.global_storage then
		local global_storage = minetest.is_yes(fields.global_storage)

		local inv = meta:get_inventory()
		if global_storage then
			if not inv:is_empty("mailbox") then
				minetest.chat_send_player(pname, "Your mailbox is not empty!")
				minetest.close_formspec(pname, formname)
				return
			end
			inv:set_size("mailbox", 0)

			local m = storage:get_string("mailbox-" .. pname)
			if not m or m == "" then
				storage:set_string("mailbox-" .. pname, "return {}")
			end
		else
			inv:set_size("mailbox", 8 * 4)
		end

		meta:set_string("storage_method", global_storage and "player" or "")
		minetest.show_formspec(pname, formname,
			mailbox.get_formspec(pos, pname, 1))
	end
end)


function mailbox.after_place_node(pos, placer)
	local meta = minetest.get_meta(pos)
	local player_name = placer:get_player_name()

	meta:set_string("owner", player_name)
	meta:set_string("infotext", player_name.."'s Mailbox")

	local inv = meta:get_inventory()
	inv:set_size("mailbox", 8*4)
	inv:set_size("drop", 1)
end

function mailbox.on_rightclick_free(pos, _, clicker)
   local node = minetest.get_node(pos)
   node.name = "mailbox:mailbox"
   minetest.swap_node(pos, node) -- preserve Facedir
--   minetest.swap_node(pos, {name = "mailbox:mailbox" })
   mailbox.after_place_node(pos, clicker)
end

function mailbox.after_place_free(pos, placer)
	local meta = minetest.get_meta(pos)
	local player_name = placer:get_player_name()

	meta:set_string("owner", player_name)
	meta:set_string("infotext", "Free Mailbox, right-click to claim")
end


function mailbox.on_rightclick(pos, _, clicker)
	local meta = minetest.get_meta(pos)
	local player = clicker:get_player_name()
	local owner = meta:get_string("owner")
	if clicker:get_wielded_item():get_name() == "mailbox:unrenter" then
		mailbox.unrent(pos, clicker)
		return
	end
	if player == owner then
		local spos = pos.x .. "," .. pos.y .. "," .. pos.z
		minetest.show_formspec(player, "mailbox:mailbox_" .. spos,
			mailbox.get_formspec(pos, owner, 1))
	else
		minetest.show_formspec(player, "mailbox:mailbox",
			mailbox.get_formspec(pos, owner, 0))
	end
end

function mailbox.can_dig(pos, player)
	local meta = minetest.get_meta(pos)
	local owner = meta:get_string("owner")
	local player_name = player:get_player_name()
	local inv = meta:get_inventory()

	return inv:is_empty("mailbox") and player and player_name == owner
end

function mailbox.on_metadata_inventory_put(pos, listname, index, stack, player)
	if listname == "drop" then
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		if meta:get_string("storage_method") == "player" then
			inv:remove_item("drop", stack)
			stack = mailbox.send_to_player(meta:get_string('owner'), stack)
			if not stack:is_empty() then
				inv:add_item("drop", stack)
			end
		else
			if inv:room_for_item("mailbox", stack) then
				inv:remove_item("drop", stack)
				inv:add_item("mailbox", stack)
			end
		end
	end
end

function mailbox.allow_metadata_inventory_put(pos, listname, index, stack,
		player)
	if listname ~= "drop" then return 0 end
	if minetest.get_node(pos).name == "mailbox:letterbox" and
			stack:get_name() ~= "default:book_written" then
		return 0
	end

	local meta = minetest.get_meta(pos)

	if meta:get_string("storage_method") == "player" then
		if mailbox.room_for_item(meta:get_string("owner"), stack) then
			return -1
		end
	else
		local inv = meta:get_inventory()
		if inv:room_for_item("mailbox", stack) then
			return -1
		end
	end

	minetest.chat_send_player(player:get_player_name(), "Mailbox full.")
	return 0
end


minetest.register_node("mailbox:mailbox", {
	description = "Mailbox",
	tiles = {
		"mailbox_mailbox_top.png", "mailbox_mailbox_bottom.png",
		"mailbox_mailbox_side.png", "mailbox_mailbox_side.png",
		"mailbox_mailbox.png", "mailbox_mailbox.png",
	},
	groups = {cracky = 3, oddly_breakable_by_hand = 1},
	on_rotate = screwdriver.rotate_simple,
	sounds = default.node_sound_defaults(),
	paramtype2 = "facedir",
	after_place_node = mailbox.after_place_node,
	on_rightclick = mailbox.on_rightclick,
	can_dig = mailbox.can_dig,
	on_metadata_inventory_put = mailbox.on_metadata_inventory_put,
	allow_metadata_inventory_put = mailbox.allow_metadata_inventory_put,
})

minetest.register_node("mailbox:mailbox_free", {
	description = "Mailbox for Rent",
	tiles = {
		"mailbox_mailbox_free_top.png", "mailbox_mailbox_free_bottom.png",
		"mailbox_mailbox_free_side.png", "mailbox_mailbox_free_side.png",
		"mailbox_mailbox_free.png", "mailbox_mailbox_free.png",
	},
	groups = {cracky = 3, oddly_breakable_by_hand = 1},
	on_rotate = screwdriver.rotate_simple,
	sounds = default.node_sound_defaults(),
	paramtype2 = "facedir",

	after_place_node = mailbox.after_place_free,
	on_rightclick = mailbox.on_rightclick_free,
	can_dig = mailbox.can_dig,
--	on_metadata_inventory_put = mailbox.on_metadata_inventory_put,
--	allow_metadata_inventory_put = mailbox.allow_metadata_inventory_put,

})



minetest.register_node("mailbox:letterbox", {
	description = "Letterbox (you hacker you!)",
	tiles = {
		"mailbox_letterbox_top.png", "mailbox_letterbox_bottom.png",
		"mailbox_letterbox_side.png", "mailbox_letterbox_side.png",
		"mailbox_letterbox.png", "mailbox_letterbox.png",
	},
	groups = {cracky = 3, oddly_breakable_by_hand = 1, not_in_creative_inventory = 1},
	on_rotate = screwdriver.rotate_simple,
	sounds = default.node_sound_defaults(),
	paramtype2 = "facedir",
	drop = "mailbox:mailbox",
	after_place_node = mailbox.after_place_node,
	on_rightclick = mailbox.on_rightclick,
	can_dig = mailbox.can_dig,
	on_metadata_inventory_put = mailbox.on_metadata_inventory_put,
	allow_metadata_inventory_put = mailbox.allow_metadata_inventory_put,
})

minetest.register_tool("mailbox:unrenter", {
    description = "Unrenter",
    inventory_image = "mailbox_unrent.png",
})


minetest.register_craft({
	output = "mailbox:mailbox",
	recipe = {
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
		{"default:book", "default:chest", "default:book"},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
	}
})
