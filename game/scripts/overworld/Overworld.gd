extends Node3D
class_name Overworld

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const NPC_SHIP_SCENE := preload("res://game/scenes/OverworldNpcShip.tscn")

@export var player_path: NodePath
@export var intercept_distance: float = 14.0
@export var intercept_radius_per_scale: float = 2.8

var player: Node3D
var npc_ships: Array[Node3D] = []
var nearest_intercept: Node3D


func _ready() -> void:
	player = get_node_or_null(player_path) as Node3D
	var session := get_node_or_null("/root/GameSession")
	if player and session:
		player.global_position = session.last_overworld_player_position
	_spawn_npcs()


func _process(_delta: float) -> void:
	_update_nearest_intercept()
	if nearest_intercept and Input.is_action_just_pressed("intercept"):
		var session := get_node_or_null("/root/GameSession")
		if session:
			session.start_encounter(nearest_intercept.get("encounter_record"), player.global_position)


func get_nearest_intercept_label() -> String:
	if nearest_intercept == null:
		return "None"
	var record: Dictionary = nearest_intercept.get("encounter_record")
	return "%s - Press Enter" % str(record.get("name", nearest_intercept.name))


func _spawn_npcs() -> void:
	var session := get_node_or_null("/root/GameSession")
	for record in ContentCatalog.load_overworld_ship_records():
		var encounter_id := str(record.get("id", ""))
		if session and session.is_encounter_defeated(encounter_id):
			continue
		var npc := NPC_SHIP_SCENE.instantiate() as Node3D
		add_child(npc)
		npc.call("configure", record)
		npc_ships.append(npc)


func _update_nearest_intercept() -> void:
	nearest_intercept = null
	if player == null:
		return
	var nearest_distance := INF
	for npc in npc_ships:
		var intercept_range := _get_intercept_range(player, npc)
		var distance := player.global_position.distance_to(npc.global_position)
		if distance <= intercept_range and distance < nearest_distance:
			nearest_distance = distance
			nearest_intercept = npc


func _get_intercept_range(player_ship: Node3D, npc_ship: Node3D) -> float:
	var player_radius := player_ship.scale.x * intercept_radius_per_scale if player_ship else 0.0
	var npc_radius := npc_ship.scale.x * intercept_radius_per_scale if npc_ship else 0.0
	return intercept_distance + player_radius + npc_radius
