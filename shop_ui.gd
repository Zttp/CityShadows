extends CanvasLayer

@onready var item_list = $Panel/ItemList
@onready var title_label = $Panel/TitleLabel

var shop_type: String
var items: Array[Dictionary]
var shop_ref: AccessoryShop

func init(type: String, shop_items: Array[Dictionary], shop: AccessoryShop):
    shop_type = type
    items = shop_items.filter(func(item): return item["id"].begins_with(type))
    shop_ref = shop
    title_label.text = "Магазин %s" % type.capitalize()
    populate_list()

func populate_list():
    item_list.clear()
    for item in items:
        item_list.add_item("%s - $%d" % [item["name"], item["price"]])

func _on_item_list_item_selected(index):
    if index >= 0 and index < items.size():
        var item = items[index]
        if shop_ref.purchase_item(item["id"], item["price"]):
            item_list.set_item_disabled(index, true)

func _on_close_button_pressed():
    queue_free()
