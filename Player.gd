extends CharacterBody2D

# Состояния игрока
enum PlayerState { NORMAL, RELOADING, SHOPPING, DIALOGUE }

# Настройки движения
@export var move_speed: float = 150.0
@export var acceleration: float = 10.0
@export var friction: float = 15.0

# Статистика игрока
var health: float = 100.0
var max_health: float = 100.0
var armor: float = 0.0
var max_armor: float = 100.0
var money: int = 500
var faction: String = "neutral" # "police", "bandits", "military"
var faction_rank: int = 1
var reputation: Dictionary = {
    "police": 0,
    "bandits": 0,
    "military": 0
}

# Система одежды
var clothing: Dictionary = {
    "hat": null,
    "glasses": null,
    "mouth": null
}

# Система оружия
var weapons: Array = []
var current_weapon_index: int = -1
var current_weapon: Dictionary = {
    "name": "Fists",
    "damage": 10,
    "ammo": 0,
    "max_ammo": 0,
    "clip_size": 0,
    "current_clip": 0,
    "reload_time": 0,
    "fire_rate": 0,
    "range": 50,
    "texture": null
}

# Таймеры и состояния
var reload_timer: float = 0.0
var fire_cooldown: float = 0.0
var current_state: PlayerState = PlayerState.NORMAL
var last_direction: Vector2 = Vector2.DOWN

# Ссылки на узлы
@onready var sprite: Sprite2D = $Sprite2D
@onready var clothing_layer: Node2D = $ClothingLayer
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite
@onready var hud: CanvasLayer = $HUD
@onready var health_bar: TextureProgressBar = $HUD/HealthBar
@onready var armor_bar: TextureProgressBar = $HUD/ArmorBar
@onready var ammo_label: Label = $HUD/AmmoLabel
@onready var money_label: Label = $HUD/MoneyLabel
@onready var faction_icon: TextureRect = $HUD/FactionIcon

func _ready():
    # Инициализация HUD
    update_hud()
    
    # Загрузка сохраненных данных
    load_player_data()
    
    # Начальное оружие (кулаки)
    weapons.append({
        "name": "Fists",
        "damage": 10,
        "ammo": 0,
        "max_ammo": 0,
        "clip_size": 0,
        "current_clip": 0,
        "reload_time": 0,
        "fire_rate": 0.5,
        "range": 50,
        "texture": null
    })
    switch_weapon(0)

func _physics_process(delta: float):
    match current_state:
        PlayerState.NORMAL:
            process_movement(delta)
            process_combat(delta)
            process_interaction()
        PlayerState.RELOADING:
            process_reloading(delta)
            process_movement(delta)
        PlayerState.SHOPPING, PlayerState.DIALOGUE:
            pass

func process_movement(delta: float):
    var input_vector: Vector2 = Input.get_vector("left", "right", "up", "down")
    
    if input_vector.length() > 0:
        velocity = velocity.lerp(input_vector * move_speed, acceleration * delta)
        last_direction = input_vector.normalized()
        
        # Обновляем поворот оружия
        weapon_pivot.rotation = last_direction.angle()
    else:
        velocity = velocity.lerp(Vector2.ZERO, friction * delta)
    
    move_and_slide()

func process_combat(delta: float):
    # Обработка переключения оружия
    if Input.is_action_just_pressed("weapon_next"):
        switch_weapon((current_weapon_index + 1) % weapons.size())
    elif Input.is_action_just_pressed("weapon_prev"):
        switch_weapon((current_weapon_index - 1) % weapons.size())
    
    # Обработка стрельбы
    if fire_cooldown > 0:
        fire_cooldown -= delta
    
    if Input.is_action_pressed("shoot") and fire_cooldown <= 0 and current_weapon["current_clip"] > 0:
        shoot()
    elif Input.is_action_just_pressed("reload") and current_weapon["clip_size"] > 0 and current_weapon["current_clip"] < current_weapon["clip_size"] and current_weapon["ammo"] > 0:
        start_reload()

func process_interaction():
    if Input.is_action_just_pressed("interact"):
        var interactables = $InteractionArea.get_overlapping_areas()
        for interactable in interactables:
            if interactable.has_method("interact"):
                interactable.interact(self)
                break

func process_reloading(delta: float):
    reload_timer -= delta
    if reload_timer <= 0:
        finish_reload()

func shoot():
    if current_weapon["current_clip"] <= 0:
        return
    
    current_weapon["current_clip"] -= 1
    fire_cooldown = 1.0 / current_weapon["fire_rate"]
    
    # Создаем луч для проверки попадания
    var space_state = get_world_2d().direct_space_state
    var start = global_position
    var end = start + last_direction * current_weapon["range"]
    var query = PhysicsRayQueryParameters2D.create(start, end)
    query.collide_with_areas = false
    query.collision_mask = 0b1
    
    var result = space_state.intersect_ray(query)
    if result:
        var target = result["collider"]
        if target.has_method("take_damage"):
            var damage = current_weapon["damage"]
            # Модификаторы урона в зависимости от фракции
            if faction == "police" and target.faction == "bandits":
                damage *= 1.2
            elif faction == "bandits" and target.faction == "police":
                damage *= 1.1
            target.take_damage(damage)
    
    update_hud()

func start_reload():
    if current_weapon["ammo"] <= 0 or current_weapon["current_clip"] == current_weapon["clip_size"]:
        return
    
    current_state = PlayerState.RELOADING
    reload_timer = current_weapon["reload_time"]
    # Здесь можно добавить анимацию перезарядки

func finish_reload():
    var ammo_needed = current_weapon["clip_size"] - current_weapon["current_clip"]
    var ammo_to_use = min(ammo_needed, current_weapon["ammo"])
    
    current_weapon["current_clip"] += ammo_to_use
    current_weapon["ammo"] -= ammo_to_use
    
    current_state = PlayerState.NORMAL
    update_hud()

func switch_weapon(index: int):
    if index < 0 or index >= weapons.size():
        return
    
    current_weapon_index = index
    current_weapon = weapons[index].duplicate()
    
    if current_weapon["texture"]:
        weapon_sprite.texture = current_weapon["texture"]
        weapon_sprite.visible = true
    else:
        weapon_sprite.visible = false
    
    update_hud()

func take_damage(amount: float):
    var damage = amount
    
    # Сначала урон идет по броне
    if armor > 0:
        var armor_damage = min(armor, damage * 0.7)
        armor -= armor_damage
        damage -= armor_damage * 0.5  # Броня поглощает часть урона
    
    # Оставшийся урон идет по здоровью
    health -= damage
    
    # Проверка на смерть
    if health <= 0:
        die()
    
    update_hud()

func heal(amount: float):
    health = min(health + amount, max_health)
    update_hud()

func add_armor(amount: float):
    armor = min(armor + amount, max_armor)
    update_hud()

func add_money(amount: int):
    money += amount
    update_hud()

func spend_money(amount: int) -> bool:
    if money >= amount:
        money -= amount
        update_hud()
        return true
    return false

func change_faction(new_faction: String):
    faction = new_faction
    update_hud()
    save_player_data()

func equip_clothing(type: String, texture: Texture2D):
    clothing[type] = texture
    match type:
        "hat":
            clothing_layer.get_node("HatSprite").texture = texture
            clothing_layer.get_node("HatSprite").visible = texture != null
        "glasses":
            clothing_layer.get_node("GlassesSprite").texture = texture
            clothing_layer.get_node("GlassesSprite").visible = texture != null
        "mouth":
            clothing_layer.get_node("MouthSprite").texture = texture
            clothing_layer.get_node("MouthSprite").visible = texture != null
    save_player_data()

func add_weapon(weapon_data: Dictionary):
    weapons.append(weapon_data)
    switch_weapon(weapons.size() - 1)
    save_player_data()

func update_hud():
    # Обновление здоровья и брони
    health_bar.value = health
    armor_bar.value = armor
    
    # Обновление информации об оружии
    if current_weapon["clip_size"] > 0:
        ammo_label.text = "%d/%d" % [current_weapon["current_clip"], current_weapon["ammo"]]
    else:
        ammo_label.text = "∞"
    
    # Обновление денег
    money_label.text = "$%d" % money
    
    # Обновление иконки фракции
    match faction:
        "police":
            faction_icon.texture = preload("res://assets/ui/police_icon.png")
        "bandits":
            faction_icon.texture = preload("res://assets/ui/bandit_icon.png")
        "military":
            faction_icon.texture = preload("res://assets/ui/military_icon.png")
        _:
            faction_icon.texture = null

func die():
    # Обработка смерти игрока
    print("Player died!")
    # Здесь можно добавить эффекты смерти, респавн и т.д.
    health = max_health
    armor = 0
    position = Vector2.ZERO  # Респавн в начале уровня
    update_hud()

func save_player_data():
    var save_data = {
        "health": health,
        "armor": armor,
        "money": money,
        "faction": faction,
        "faction_rank": faction_rank,
        "reputation": reputation,
        "clothing": clothing,
        "weapons": weapons,
        "current_weapon_index": current_weapon_index,
        "position": {
            "x": position.x,
            "y": position.y
        }
    }
    
    var save_file = FileAccess.open("user://player_save.dat", FileAccess.WRITE)
    save_file.store_var(save_data)
    save_file.close()

func load_player_data():
    if FileAccess.file_exists("user://player_save.dat"):
        var save_file = FileAccess.open("user://player_save.dat", FileAccess.READ)
        var save_data = save_file.get_var()
        save_file.close()
        
        health = save_data["health"]
        armor = save_data["armor"]
        money = save_data["money"]
        faction = save_data["faction"]
        faction_rank = save_data["faction_rank"]
        reputation = save_data["reputation"]
        clothing = save_data["clothing"]
        weapons = save_data["weapons"]
        current_weapon_index = save_data["current_weapon_index"]
        
        # Применяем сохраненную одежду
        for type in clothing:
            if clothing[type]:
                var texture = load(clothing[type])
                equip_clothing(type, texture)
        
        # Восстанавливаем позицию
        position = Vector2(save_data["position"]["x"], save_data["position"]["y"])
        
        # Восстанавливаем текущее оружие
        if current_weapon_index >= 0 and current_weapon_index < weapons.size():
            switch_weapon(current_weapon_index)
        
        update_hud()
