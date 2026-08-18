extends Node3D
class_name NavalBattle

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

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


func _unhandled_input(event: InputEvent) -> void:
	# A practice battle is a test, not a campaign, so the tester can break it off
	# the moment it has shown them what they wanted and go straight back to the
	# loadout screen. The campaign has no such escape.
	if not event.is_action_pressed("ui_cancel"):
		return
	var session := get_node_or_null("/root/GameSession")
	if session and bool(session.get("practice_mode")):
		get_viewport().set_input_as_handled()
		session.abandon_battle()


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
			session.finish_battle(pending_result, build_report(pending_result))


func _check_result() -> void:
	# A struck ship is beaten without being sunk: the enemy is a prize, or the
	# player lost the boarding duel on their own deck (ADR 0011).
	if player_ship and bool(player_ship.get("is_sunk")):
		_set_result("player_sunk")
	elif player_ship and bool(player_ship.get("has_struck_colors")):
		_set_result("player_defeated")
	elif target_ship and bool(target_ship.get("is_sunk")):
		_set_result("enemy_sunk")
	elif target_ship and bool(target_ship.get("has_struck_colors")):
		_set_result("enemy_captured")


# Everything the after-action screen needs to say what happened and offer what
# can be done about it. Assembled here because this is the only place that can
# still see both ships; once the scene changes the state is gone.
func build_report(result: String) -> Dictionary:
	var report := {
		"result": result,
		"player": _describe_ship(player_ship),
		"enemy": _describe_ship(target_ship)
	}
	# What she was carrying is the prize. Sunk ships keep most of it: only what
	# floats can be fished out, and that is decided by the after-action screen.
	var enemy_loadout: Dictionary = target_ship.get("ship_loadout") if target_ship else {}
	report["enemy_loadout"] = enemy_loadout.duplicate(true) if enemy_loadout else {}
	report["enemy_manifest"] = report["enemy_loadout"].get("cargo", {}).duplicate()
	report["enemy_name"] = str(target_ship.get("ship_display_name")) if target_ship else "Enemy Ship"
	return report


func _describe_ship(ship: Node) -> Dictionary:
	if ship == null:
		return {}
	var combat := ship.get_node_or_null("ShipCombatComponent")
	if combat == null or not combat.has_method("export_condition"):
		return {}
	var condition: Dictionary = combat.call("export_condition")
	condition["sunk"] = bool(ship.get("is_sunk"))
	condition["struck_colors"] = bool(ship.get("has_struck_colors"))
	return condition


func _set_result(result: String) -> void:
	pending_result = result
	result_timer = result_delay
