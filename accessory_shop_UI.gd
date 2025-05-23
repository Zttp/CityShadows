extends PanelContainer

@onready var item_list = $VBoxContainer/ItemList
@onready var money_label = $VBoxContainer/MoneyLabel
@onready var preview = $VBoxContainer/Preview

var items: Array
var player: Node

func setup(store_items: Array, player_node: Node):
    items = store_items
    player = player_node
    
    money_label.text = "Money: $%d" % player.money
    
    for item in items:
        item_list.add_item("%s - $%d" % [item["name"], item["price"]])

func _on_item_list_item_selected(index):
    var item = items[index]
    var texture = load(item["texture_path"])
    
    # Обновляем превью
    match item["type"]:
        "hat":
            preview.get_node("Hat").texture = texture
        "glasses":
            preview.get_node("Glasses").texture = texture
        "mouth":
            preview.get_node("Mouth").texture = texture

func _on_buy_button_pressed():
    var selected = item_list.get_selected_items()
    if selected.size() > 0:
        var index = selected[0]
        var item = items[index]
        
        if player.spend_money(item["price"]):
            var texture = load(item["texture_path"])
            player.equip_clothing(item["type"], texture)
            money_label.text = "Money: $%d" % player.money

func _on_exit_button_pressed():
    player.current_state = player.PlayerState.NORMAL
    queue_free()
