extends Area2D

class_name AccessoryShop

@export var shop_type: String = "hat" # hat/eyes/mouth
@export var items: Array[Dictionary] = [
    {"id": "hat1", "name": "Кепка", "price": 50},
    {"id": "hat2", "name": "Шляпа", "price": 100},
    {"id": "angry", "name": "Злые глаза", "price": 30},
    {"id": "smile", "name": "Улыбка", "price": 40}
]

var player_in_shop: bool = false
var player_ref: Node2D = null

func _ready():
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body):
    if body.name == "Player":
        player_in_shop = true
        player_ref = body
        show_shop_ui()

func _on_body_exited(body):
    if body.name == "Player":
        player_in_shop = false
        player_ref = null
        hide_shop_ui()

func show_shop_ui():
    var ui = preload("res://scenes/ui/shop_ui.tscn").instantiate()
    ui.init(shop_type, items, self)
    get_tree().current_scene.add_child(ui)

func hide_shop_ui():
    var ui = get_tree().current_scene.get_node("ShopUI")
    if ui:
        ui.queue_free()

func purchase_item(item_id: String, item_price: int):
    if player_ref:
        return player_ref.equip_accessory(shop_type, item_id, item_price)
    return false
