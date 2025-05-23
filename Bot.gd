extends CharacterBody2D

class_name Bot

# Фракции и ранги
enum Faction { POLICE, BANDIT, MILITARY }
enum Rank { LOW, MEDIUM, HIGH, LEADER }

# Состояния бота
enum State {
    IDLE,           # Ожидание
    PATROL,         # Патрулирование
    CHASE,          # Преследование
    ATTACK,         # Атака
    FLEE,           # Бегство
    INVESTIGATE,    # Исследование шума
    COVER,          # Укрытие
    TRADING,        # Торговля (для нейтральных NPC)
    BETRAY          # Предательское поведение
}

# Настройки бота
@export var faction: Faction = Faction.POLICE
@export var rank: Rank = Rank.LOW
@export var is_traitor: bool = false
@export var move_speed: float = 120.0
@export var chase_speed: float = 180.0
@export var rotation_speed: float = 5.0
@export var health: float = 100.0
@export var armor: float = 0.0
@export var accuracy: float = 0.7  # Точность стрельбы (0-1)

# Оружие и боеприпасы
var weapons: Array = []
var current_weapon: Dictionary = {
    "name": "Pistol",
    "damage": 25,
    "range": 300,
    "fire_rate": 2.0,
    "ammo": 30,
    "clip_size": 10,
    "current_clip": 10
}

# Навигация и ИИ
var path: PackedVector2Array = []
var target_position: Vector2 = Vector2.ZERO
var current_target: Node2D = null
var last_known_position: Vector2 = Vector2.ZERO
var suspicion_level: float = 0.0
var memory_timer: float = 0.0
var reload_timer: float = 0.0
var fire_cooldown: float = 0.0

# Черты характера (для разнообразия поведения)
var traits: Dictionary = {
    "aggressiveness": randf_range(0.3, 0.8),
    "courage": randf_range(0.4, 0.9),
    "intelligence": randf_range(0.5, 1.0),
    "loyalty": randf_range(0.1, 0.9)
}

# Ссылки на узлы
@onready var state_machine: Node = $StateMachine
@onready var vision_cone: Area2D = $VisionCone
@onready var detection_area: Area2D = $DetectionArea
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite
@onready var faction_indicator: Sprite2D = $FactionIndicator
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready():
    # Инициализация в зависимости от фракции
    setup_faction()
    
    # Настройка цвета индикатора фракции
    match faction:
        Faction.POLICE:
            faction_indicator.modulate = Color("1e90ff")
        Faction.BANDIT:
            faction_indicator.modulate = Color("ff4500")
        Faction.MILITARY:
            faction_indicator.modulate = Color("228b22")
    
    # Инициализация оружия
    setup_weapons()
    
    # Подписка на сигналы
    nav_agent.path_changed.connect(_on_path_changed)
    vision_cone.body_entered.connect(_on_vision_cone_body_entered)
    detection_area.body_entered.connect(_on_detection_area_body_entered)

func _physics_process(delta: float):
    # Обновление таймеров
    if memory_timer > 0:
        memory_timer -= delta
        if memory_timer <= 0:
            forget_target()
    
    if reload_timer > 0:
        reload_timer -= delta
        if reload_timer <= 0:
            finish_reload()
    
    if fire_cooldown > 0:
        fire_cooldown -= delta
    
    # Обработка текущего состояния
    match state_machine.current_state:
        State.IDLE:
            process_idle(delta)
        State.PATROL:
            process_patrol(delta)
        State.CHASE:
            process_chase(delta)
        State.ATTACK:
            process_attack(delta)
        State.FLEE:
            process_flee(delta)
        State.INVESTIGATE:
            process_investigate(delta)
        State.BETRAY:
            process_betray(delta)
    
    move_and_slide()

func setup_faction():
    # Настройка характеристик в зависимости от фракции и ранга
    match faction:
        Faction.POLICE:
            move_speed *= 1.1
            accuracy *= 1.1
            if rank == Rank.LEADER:
                health *= 1.5
                armor = 50.0
        Faction.BANDIT:
            chase_speed *= 1.15
            traits["aggressiveness"] *= 1.2
            if rank == Rank.LEADER:
                health *= 1.3
        Faction.MILITARY:
            health *= 1.2
            armor = 30.0
            accuracy *= 1.2
            if rank == Rank.LEADER:
                health *= 1.8
                armor = 80.0
    
    # Предатели имеют особые характеристики
    if is_traitor:
        traits["loyalty"] = 0.1
        traits["aggressiveness"] *= 1.3
        move_speed *= 1.1

func setup_weapons():
    # Выдача оружия в зависимости от фракции и ранга
    match faction:
        Faction.POLICE:
            weapons.append({
                "name": "Pistol",
                "damage": 25,
                "range": 300,
                "fire_rate": 2.0,
                "ammo": 30,
                "clip_size": 10,
                "current_clip": 10
            })
            if rank >= Rank.MEDIUM:
                weapons.append({
                    "name": "Shotgun",
                    "damage": 40,
                    "range": 200,
                    "fire_rate": 1.0,
                    "ammo": 20,
                    "clip_size": 5,
                    "current_clip": 5
                })
        Faction.BANDIT:
            weapons.append({
                "name": "Knife",
                "damage": 15,
                "range": 50,
                "fire_rate": 1.5,
                "ammo": 0,
                "clip_size": 0,
                "current_clip": 0
            })
            weapons.append({
                "name": "Pistol",
                "damage": 20,
                "range": 250,
                "fire_rate": 1.8,
                "ammo": 20,
                "clip_size": 10,
                "current_clip": 10
            })
            if rank >= Rank.HIGH:
                weapons.append({
                    "name": "SMG",
                    "damage": 15,
                    "range": 200,
                    "fire_rate": 5.0,
                    "ammo": 90,
                    "clip_size": 30,
                    "current_clip": 30
                })
        Faction.MILITARY:
            weapons.append({
                "name": "Assault Rifle",
                "damage": 30,
                "range": 400,
                "fire_rate": 4.0,
                "ammo": 120,
                "clip_size": 30,
                "current_clip": 30
            })
            if rank >= Rank.HIGH:
                weapons.append({
                    "name": "Sniper Rifle",
                    "damage": 80,
                    "range": 800,
                    "fire_rate": 0.7,
                    "ammo": 20,
                    "clip_size": 5,
                    "current_clip": 5
                })
    
    current_weapon = weapons[0]
    update_weapon_sprite()

func update_weapon_sprite():
    if current_weapon["name"] == "Knife":
        weapon_sprite.texture = preload("res://assets/weapons/knife.png")
    elif current_weapon["name"] == "Pistol":
        weapon_sprite.texture = preload("res://assets/weapons/pistol.png")
    # ... другие текстуры оружия

func take_damage(damage: float, attacker: Node2D = null):
    # Сначала урон идет по броне
    var actual_damage = damage
    if armor > 0:
        var armor_damage = min(armor, damage * 0.7)
        armor -= armor_damage
        actual_damage = damage - armor_damage * 0.5
    
    health -= actual_damage
    
    # Реакция на получение урона
    if attacker and state_machine.current_state != State.FLEE:
        if is_traitor and attacker.faction == faction:
            # Предатель может использовать это как предлог для атаки "союзников"
            start_betrayal(attacker)
        else:
            set_target(attacker)
        
        if health < 30.0 and randf() < traits["courage"]:
            state_machine.change_state(State.FLEE)
        elif state_machine.current_state == State.IDLE or state_machine.current_state == State.PATROL:
            state_machine.change_state(State.ATTACK)
    
    if health <= 0:
        die()

func die():
    # Эффекты смерти
    queue_free()
    # Можно добавить дроп предметов, эффекты и т.д.

func set_target(target: Node2D):
    if target == self:
        return
    
    current_target = target
    last_known_position = target.global_position
    memory_timer = 10.0  # Время памяти о цели
    
    # Реакция в зависимости от фракции цели
    if target.has_method("get_faction"):
        var target_faction = target.get_faction()
        
        # Полиция атакует бандитов и предателей
        if faction == Faction.POLICE:
            if target_faction == Faction.BANDIT or (target_faction == Faction.POLICE and target.is_traitor):
                state_machine.change_state(State.CHASE)
        
        # Бандиты атакуют полицию и предателей
        elif faction == Faction.BANDIT:
            if target_faction == Faction.POLICE or (target_faction == Faction.BANDIT and target.is_traitor):
                state_machine.change_state(State.CHASE)
        
        # Военные атакуют бандитов и предателей
        elif faction == Faction.MILITARY:
            if target_faction == Faction.BANDIT or (target_faction == Faction.MILITARY and target.is_traitor):
                state_machine.change_state(State.CHASE)
    
    # Предатели могут атаковать своих
    if is_traitor and target.faction == faction and randf() > traits["loyalty"]:
        start_betrayal(target)

func start_betrayal(target: Node2D):
    # Предательское поведение
    state_machine.change_state(State.BETRAY)
    current_target = target
    # Можно добавить особые действия предателя

func forget_target():
    current_target = null
    if state_machine.current_state == State.CHASE or state_machine.current_state == State.ATTACK:
        state_machine.change_state(State.INVESTIGATE)

func process_idle(delta: float):
    # Случайные движения на месте
    if randf() < 0.02:
        velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * move_speed * 0.3
    else:
        velocity = velocity.lerp(Vector2.ZERO, 0.1)
    
    # Переход в патруль
    if randf() < 0.01:
        state_machine.change_state(State.PATROL)

func process_patrol(delta: float):
    # Движение по случайным точкам
    if path.is_empty() or global_position.distance_to(path[-1]) < 10.0:
        generate_new_patrol_point()
    
    if not path.is_empty():
        var next_point = path[0]
        var direction = (next_point - global_position).normalized()
        velocity = velocity.lerp(direction * move_speed, 0.1)
        
        if global_position.distance_to(next_point) < 5.0:
            path.remove_at(0)
    
    # Поворот оружия в направлении движения
    if velocity.length() > 0.1:
        weapon_pivot.rotation = velocity.angle()

func process_chase(delta: float):
    if current_target:
        last_known_position = current_target.global_position
        nav_agent.target_position = last_known_position
        
        if not path.is_empty():
            var next_point = path[0]
            var direction = (next_point - global_position).normalized()
            velocity = velocity.lerp(direction * chase_speed, 0.2)
            
            if global_position.distance_to(next_point) < 5.0:
                path.remove_at(0)
        
        # Проверка видимости цели
        if has_line_of_sight(current_target):
            state_machine.change_state(State.ATTACK)
        
        # Поворот оружия в направлении цели
        if current_target:
            weapon_pivot.rotation = (current_target.global_position - global_position).angle()
    else:
        state_machine.change_state(State.INVESTIGATE)

func process_attack(delta: float):
    if not current_target:
        state_machine.change_state(State.INVESTIGATE)
        return
    
    # Движение к цели или укрытию
    if global_position.distance_to(current_target.global_position) < current_weapon["range"] * 0.7:
        # Ищем укрытие
        find_cover()
    else:
        nav_agent.target_position = current_target.global_position
        if not path.is_empty():
            var next_point = path[0]
            var direction = (next_point - global_position).normalized()
            velocity = velocity.lerp(direction * move_speed, 0.2)
            
            if global_position.distance_to(next_point) < 5.0:
                path.remove_at(0)
    
    # Стрельба
    if has_line_of_sight(current_target) and fire_cooldown <= 0:
        if current_weapon["current_clip"] > 0:
            shoot_at(current_target)
        elif current_weapon["ammo"] > 0:
            start_reload()
    
    # Поворот оружия в направлении цели
    weapon_pivot.rotation = (current_target.global_position - global_position).angle()

func process_flee(delta: float):
    if current_target:
        var flee_direction = (global_position - current_target.global_position).normalized()
        var flee_target = global_position + flee_direction * 500.0
        nav_agent.target_position = flee_target
        
        if not path.is_empty():
            var next_point = path[0]
            var direction = (next_point - global_position).normalized()
            velocity = velocity.lerp(direction * chase_speed * 1.2, 0.3)
            
            if global_position.distance_to(next_point) < 5.0:
                path.remove_at(0)
    
    # Возвращение к нормальному состоянию
    if health > 50.0 or not current_target:
        state_machine.change_state(State.IDLE)

func process_investigate(delta: float):
    if last_known_position != Vector2.ZERO:
        nav_agent.target_position = last_known_position
        
        if not path.is_empty():
            var next_point = path[0]
            var direction = (next_point - global_position).normalized()
            velocity = velocity.lerp(direction * move_speed * 0.8, 0.1)
            
            if global_position.distance_to(next_point) < 5.0:
                path.remove_at(0)
        
        if global_position.distance_to(last_known_position) < 20.0:
            # Осмотр области
            last_known_position = Vector2.ZERO
            state_machine.change_state(State.IDLE)
    else:
        state_machine.change_state(State.IDLE)

func process_betray(delta: float):
    # Особое поведение предателя
    if current_target:
        if current_target.faction == faction:
            # Предатель атакует своих
            if global_position.distance_to(current_target.global_position) < current_weapon["range"]:
                if has_line_of_sight(current_target) and fire_cooldown <= 0:
                    shoot_at(current_target)
            else:
                nav_agent.target_position = current_target.global_position
                if not path.is_empty():
                    var next_point = path[0]
                    var direction = (next_point - global_position).normalized()
                    velocity = velocity.lerp(direction * move_speed, 0.2)
                    
                    if global_position.distance_to(next_point) < 5.0:
                        path.remove_at(0)
        else:
            # Предатель может притвориться союзником
            state_machine.change_state(State.IDLE)
    else:
        state_machine.change_state(State.IDLE)

func shoot_at(target: Node2D):
    if fire_cooldown > 0 or current_weapon["current_clip"] <= 0:
        return
    
    current_weapon["current_clip"] -= 1
    fire_cooldown = 1.0 / current_weapon["fire_rate"]
    
    # Расчет попадания с учетом точности
    var hit_chance = accuracy * (0.8 + 0.2 * traits["intelligence"])
    if randf() > hit_chance:
        return  # Промах
    
    var actual_damage = current_weapon["damage"]
    
    # Модификаторы урона в зависимости от фракции
    if faction == Faction.POLICE and target.get_faction() == Faction.BANDIT:
        actual_damage *= 1.2
    elif faction == Faction.BANDIT and target.get_faction() == Faction.POLICE:
        actual_damage *= 1.1
    
    target.take_damage(actual_damage, self)
    
    # Звук выстрела может привлечь других ботов
    alert_nearby_allies()

func start_reload():
    if current_weapon["ammo"] <= 0 or current_weapon["current_clip"] == current_weapon["clip_size"]:
        return
    
    reload_timer = current_weapon["reload_time"] * (1.1 - 0.2 * traits["intelligence"])

func finish_reload():
    var ammo_needed = current_weapon["clip_size"] - current_weapon["current_clip"]
    var ammo_to_use = min(ammo_needed, current_weapon["ammo"])
    
    current_weapon["current_clip"] += ammo_to_use
    current_weapon["ammo"] -= ammo_to_use

func has_line_of_sight(target: Node2D) -> bool:
    var space_state = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(
        global_position,
        target.global_position
    )
    query.collide_with_areas = true
    query.collision_mask = 0b1
    
    var result = space_state.intersect_ray(query)
    return result.is_empty() or result["collider"] == target

func generate_new_patrol_point():
    var patrol_range = 200.0
    var new_point = global_position + Vector2(
        randf_range(-patrol_range, patrol_range),
        randf_range(-patrol_range, patrol_range)
    )
    nav_agent.target_position = new_point

func find_cover():
    # Простой алгоритм поиска укрытия
    var cover_positions = []
    var cover_radius = 150.0
    
    for i in range(4):
        var angle = i * PI / 2
        var cover_pos = global_position + Vector2(cos(angle), sin(angle)) * cover_radius
        cover_positions.append(cover_pos)
    
    # Выбираем лучшую позицию
    var best_pos = global_position
    var best_score = 0.0
    
    for pos in cover_positions:
        var score = 0.0
        if not has_line_of_sight_to_point(pos, current_target.global_position):
            score += 100.0
        score += global_position.distance_to(pos)
        
        if score > best_score:
            best_score = score
            best_pos = pos
    
    nav_agent.target_position = best_pos

func has_line_of_sight_to_point(point: Vector2, target_point: Vector2) -> bool:
    var space_state = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(point, target_point)
    query.collide_with_areas = true
    query.collision_mask = 0b1
    
    var result = space_state.intersect_ray(query)
    return result.is_empty()

func alert_nearby_allies():
    var allies = detection_area.get_overlapping_bodies()
    for ally in allies:
        if ally != self and ally.has_method("get_faction") and ally.get_faction() == faction:
            if current_target and ally.current_target != current_target:
                ally.set_target(current_target)

func get_faction() -> Faction:
    return faction

func _on_path_changed():
    path = nav_agent.get_current_navigation_path()

func _on_vision_cone_body_entered(body: Node2D):
    if body == self:
        return
    
    # Проверка на видимость
    if has_line_of_sight(body):
        set_target(body)

func _on_detection_area_body_entered(body: Node2D):
    if body == self:
        return
    
    # Реакция на звуки (например, выстрелы)
    if body.has_method("get_faction"):
        var body_faction = body.get_faction()
        
        # Полиция реагирует на выстрелы бандитов
        if faction == Faction.POLICE and body_faction == Faction.BANDIT:
            set_target(body)
        
        # Бандиты реагируют на приближение полиции
        elif faction == Faction.BANDIT and body_faction == Faction.POLICE:
            set_target(body)
        
        # Военные реагируют на бандитов
        elif faction == Faction.MILITARY and body_faction == Faction.BANDIT:
            set_target(body)
