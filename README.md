# mailbox

A mod that adds mailboxes, based on the "old" xdecor mailboxes.

## Original description

Thanks to @SmallJoker AKA Krock for helping me with the minetest.swap_node part
of the mod!

## Global storage

There is a "global storage" option in mailboxes that shares items between
multiple mailboxes. The inventories for these mailboxes are stored in mod
storage and temporarily loaded into a player inventory list for online players.

### Global storage API

 - `mailbox.room_for_item(player_or_name, item)`: Checks if `player_or_name`'s
    global mailbox inventory can fit `item`. This may return `false` for
    offline players without a global mailbox inventory.
 - `mailbox.send_to_player(player_or_name, item)`: Sends `item` to
    `player_or_name`'s global mailbox inventory. Returns an ItemStack
    containing whatever couldn't fit into the mailbox.
 - `mailbox.get_mailbox_inv_list(name)`: Similar to
    `player:get_inventory():get_list("mailbox")`, however also works with
    offline players.
 - `mailbox.set_mailbox_inv_list(name, list)`: Similar to
    `player:get_inventory():set_list("mailbox", new_list)`, however also works
    with offline players and saves the inventory list correctly.

*Note that setting a player's `mailbox` list directly (with
`inventory:set_list()`) will **not** update the mod storage copy, and if the
server crashes or is shut down before the player logs out, the changes will not
be stored.*

Other mods can use `mailbox.get_mailbox_inv_list(name)` and
`mailbox.set_mailbox_inv_list(name, list)` to manipulate these inventories.
These functions are similar to `InvRef:get_list()`, however do not take a
`list` parameter, and `set_mailbox_inv_list()` accepts ItemStrings as well.
