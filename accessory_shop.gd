extends Area2D

@export var store_name: String = "Clothing Store"
@export var items: Array = [
    {"type": "hat", "name": "Cap", "texture_path": "res://assets/clothing/cap.png", "price": 100},
    {"type": "glasses", "name": "Sunglasses", "texture_path": "res://assets/clothing/sunglasses.png", "price": 150},
    {"type": "mouth", "name": "Cigarette", "texture_path": "res://assets/clothing/cigarette.png", "price": 50}
]

func interact(player):
    player.current_state = player.PlayerState.SHOPPING
    # Здесь можно открыть UI магазина
    var shop_ui = preload("res://ui/clothing_store_ui.tscn").instantiate()
    shop_ui.setup(items, player)
    player.get_node("HUD").add_child(shop_ui)
