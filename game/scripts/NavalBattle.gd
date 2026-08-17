extends Node3D
class_name NavalBattle

@export var player_ship_path: NodePath
@export var target_ship_path: NodePath
# Long enough for the 3.2s sinking settle (ShipCombatComponent.sink_duration)
# to finish on screen before the battle hands back to the overworld.
@export var result_delay: float = 5.0
@export var auto_return_to_overworld: bool = true

var player_ship: Node
var target_ship: Node
var result_timer: float = -1.0
var pending_result: String = ""


func _ready() -> void:
	player_ship = get_node_or_null(player_ship_path)
	target_ship = get_node_or_null(target_ship_path)


func _process(delta: float) -> void:
	if not auto_return_to_overworld:
		return
	if pending_result.is_empty():
		_check_result()
		return
	result_timer -= delta
	if result_timer <= 0.0:
		var session := get_node_or_null("/root/GameSession")
		if session:
			session.finish_battle(pending_result)


func _check_result() -> void:
	if player_ship and bool(player_ship.get("is_sunk")):
		_set_result("player_sunk")
	elif target_ship and bool(target_ship.get("is_sunk")):
		_set_result("enemy_sunk")


func _set_result(result: String) -> void:
	pending_result = result
	result_timer = result_delay
