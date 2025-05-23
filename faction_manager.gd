extends Node

signal faction_changed(new_faction)

var factions = {
    "police": {
        "name": "Police",
        "ranks": ["Rookie", "Officer", "Sergeant", "Lieutenant", "Captain"],
        "color": Color("1e90ff"),
        "weapons": ["Pistol", "Shotgun", "SMG"]
    },
    "bandits": {
        "name": "Bandits",
        "ranks": ["Thug", "Enforcer", "Lieutenant", "Underboss", "Boss"],
        "color": Color("ff4500"),
        "weapons": ["Knife", "Pistol", "SMG"]
    },
    "military": {
        "name": "Military",
        "ranks": ["Private", "Corporal", "Sergeant", "Lieutenant", "Captain"],
        "color": Color("228b22"),
        "weapons": ["Assault Rifle", "Sniper Rifle", "Shotgun"]
    }
}

func join_faction(player, faction_name: String):
    if factions.has(faction_name):
        player.change_faction(faction_name)
        emit_signal("faction_changed", faction_name)
        return true
    return false

func get_faction_info(faction_name: String):
    return factions.get(faction_name, null)

func get_available_weapons(faction_name: String):
    return factions.get(faction_name, {}).get("weapons", [])
