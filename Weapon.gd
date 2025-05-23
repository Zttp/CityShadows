extends Area2D

@export var weapon_name: String = "Pistol"
@export var damage: int = 25
@export var ammo: int = 30
@export var max_ammo: int = 90
@export var clip_size: int = 10
@export var reload_time: float = 1.5
@export var fire_rate: float = 3.0
@export var price: int = 500
@export var faction_requirement: String = "none" # "police", "bandits", "military"

func _ready():
    connect("body_entered", _on_body_entered)

func _on_body_entered(body):
    if body.has_method("add_weapon"):
        var weapon_data = {
            "name": weapon_name,
            "damage": damage,
            "ammo": ammo,
            "max_ammo": max_ammo,
            "clip_size": clip_size,
            "current_clip": clip_size,
            "reload_time": reload_time,
            "fire_rate": fire_rate,
            "range": 300,
            "texture": $Sprite2D.texture
        }
        body.add_weapon(weapon_data)
        queue_free()
