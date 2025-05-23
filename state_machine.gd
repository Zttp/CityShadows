extends Node

class_name StateMachine

@export var initial_state: Bot.State = Bot.State.IDLE

var current_state: Bot.State = initial_state
var states: Dictionary = {}

func _ready():
    # Инициализация всех состояний
    for child in get_children():
        if child is StateNode:
            states[child.state] = child
            child.state_machine = self
            child.bot = get_parent()
    
    change_state(initial_state)

func change_state(new_state: Bot.State):
    if new_state == current_state:
        return
    
    # Выход из текущего состояния
    if states.has(current_state):
        states[current_state].exit()
    
    # Вход в новое состояние
    current_state = new_state
    if states.has(current_state):
        states[current_state].enter()

func _process(delta: float):
    if states.has(current_state):
        states[current_state].update(delta)

func _physics_process(delta: float):
    if states.has(current_state):
        states[current_state].physics_update(delta)
