--
-- Mailboxes with per-player storage
--
-- Copyright © 2019 by luk3yx
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--

local storage = ...

-- This shouldn't need to be changed.
local inv_size = 4 * 8

local function get_stored_inv(name)
	local list = storage:get_string("mailbox-" .. name)
	if list then
		return minetest.deserialize(list)
	end
end

-- Sync the mailbox list on player join
minetest.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	inv:set_size("mailbox", inv_size)
	local list = get_stored_inv(player:get_player_name())
	if list then
		for id = 1, inv_size do
			list[id] = ItemStack(list[id])
		end
		inv:set_list("mailbox", list)
	end
end)

local function sync_inv(pname, inventory)
	local inv = {}
	if not inventory:is_empty("mailbox") then
		for id, item in ipairs(inventory:get_list("mailbox")) do
			if item:is_empty() then
				inv[id] = ""
			else
				inv[id] = item:to_table()
			end
		end

		-- Save space by removing trailing empty slots
		while inv[#inv] == "" do
			inv[#inv] = nil
		end
	end
	storage:set_string("mailbox-" .. pname, minetest.serialize(inv))
end

-- Don't allow players to move items around or add items to mailbox inventories
minetest.register_allow_player_inventory_action(function(player, action,
		inventory, inventory_info)
	if action == "move" then
		if inventory_info.to_list == "mailbox" then
			return 0
		end
	elseif action == "put" then
		if inventory_info.listname == "mailbox" then
			return 0
		end
	end
end)

-- Sync the mailbox inventory in case of a crash.
minetest.register_on_player_inventory_action(function(player, action,
		inventory, inventory_info)
	-- Make sure the inventory change involves the mailbox list
	if action == "move" then
		if inventory_info.from_list ~= "mailbox" and
				inventory_info.to_list ~= "mailbox" then
			return
		end
	elseif action == "put" or action == "take" then
		if inventory_info.listname ~= "mailbox" then
			return
		end
	else
		return
	end

	-- Sync the inventory with the stored copy
	sync_inv(player:get_player_name(), inventory)
end)

-- Delete(?) the player's inventory copy when they leave.
-- In case of a weird bug, also sync the inventory here.
minetest.register_on_leaveplayer(function(player)
	sync_inv(player:get_player_name(), player:get_inventory())
	player:get_inventory():set_size("mailbox", 0)
end)

local function get_player(player)
	if type(player) == "string" then
		return player, minetest.get_player_by_name(player)
	else
		return player:get_player_name(), player
	end
end

-- Check if the player's global mailbox has room for an item.
function mailbox.room_for_item(player, stack)
	local name, player = get_player(player)
	if player then
		return player:get_inventory():room_for_item("mailbox", stack)
	end

	-- Get the stored inventory
	local inv = get_stored_inv(name)
	if not inv then return false end

	-- Iterate over the expected inventory size, this way overflowing items are
	--  handled correctly.
	for id = 1, inv_size do
		stack = ItemStack(inv[id]):add_item(stack)
		if stack:is_empty() then
			return true
		end
	end

	return false
end

-- Actually send something. Returns leftover ItemStack.
function mailbox.send_to_player(player, stack)
	local name, player = get_player(player)
	if player then
		return player:get_inventory():add_item("mailbox", stack)
	end

	-- Get the stored inventory
	local inv = get_stored_inv(name)
	if not inv then return ItemStack(stack) end

	-- Iterate over it, but add things this time.
	stack = ItemStack(stack)
	local orig_count = stack:get_count()
	local modified = false
	for id = 1, inv_size do
		local i = ItemStack(inv[id])
		stack = i:add_item(stack)

		-- Put the ItemStack back if required
		modified = modified or stack:get_count() ~= orig_count
		if modified then
			if i:is_empty() then
				inv[id] = ""
			else
				inv[id] = i:to_table()
			end
		end

		-- Break out of the loop if we ran out of things to add
		if stack:is_empty() then
			break
		end
	end

	-- Save the inventory if it was modified.
	if modified then
		storage:set_string("mailbox-" .. name, minetest.serialize(inv))
	end

	-- Return the leftover ItemStack.
	return stack
end

-- Expose a few API functions for future use.
function mailbox.get_mailbox_inv_list(name)
	assert(type(name) == "string")
	local player = minetest.get_player_by_name(name)
	if player then return player:get_inventory():get_list("mailbox") end
	local inv = get_stored_inv(name)
	if inv then
		for id = 1, inv_size do
			inv[id] = ItemStack(inv[id])
		end
	end
	return inv
end

function mailbox.set_mailbox_inv_list(name, inv)
	assert(type(name) == "string" and type(inv) == "table")
	local player = minetest.get_player_by_name(name)
	local list = {}
	if player then
		-- Let sync_inv() handle everything nicely.
		for id = 1, inv_size do
			list[id] = ItemStack(inv[id])
		end
		local pinv = player:get_inventory()
		pinv:set_list("mailbox", list)
		sync_inv(name, pinv)
	else
		-- This will probably create an extra large entry, however is good
		--  enough. I may improve this in the future.
		for id = 1, inv_size do
			list[id] = ItemStack(inv[id]):to_table()
		end
		storage:set_string("mailbox-" .. name, minetest.serialize(list))
	end
end
