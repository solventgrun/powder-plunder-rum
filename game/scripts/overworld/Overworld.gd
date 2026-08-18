extends Node3D
class_name Overworld

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")
const NPC_SHIP_SCENE := preload("res://game/scenes/OverworldNpcShip.tscn")

@export var player_path: NodePath
@export var port_path: NodePath
@export var intercept_distance: float = 14.0
@export var intercept_radius_per_scale: float = 2.8
@export var port_enter_distance: float = 18.0

var player: Node3D
var port: Node3D
var npc_ships: Array[Node3D] = []
var consorts: Array[Node3D] = []
var nearest_intercept: Node3D
var port_available: bool = false


func _ready() -> void:
	player = get_node_or_null(player_path) as Node3D
	port = get_node_or_null(port_path) as Node3D
	var session := get_node_or_null("/root/GameSession")
	if player and session:
		player.global_position = session.last_overworld_player_position
	_spawn_npcs()


func _process(_delta: float) -> void:
	_update_nearest_intercept()
	_update_port_availability()
	var session := get_node_or_null("/root/GameSession")
	if Input.is_action_just_pressed("open_fleet") and session and player:
		session.open_fleet_management(false, player.global_position)
		return
	if Input.is_action_just_pressed("intercept"):
		if session == null or player == null:
			return
		if port_available:
			session.open_port(player.global_position)
		elif nearest_intercept:
			session.start_encounter(nearest_intercept.get("encounter_record"), player.global_position)


func get_nearest_intercept_label() -> String:
	if port_available:
		return "Port Royal - Press Enter"
	if nearest_intercept == null:
		return "None (M fleet)"
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
	_spawn_consorts(session)


# Prizes the player kept sail in company with the flagship. They are deliberately
# NOT added to `npc_ships`: those are intercept candidates, and you cannot board
# your own consort.
func _spawn_consorts(session: Node) -> void:
	if session == null or player == null:
		return
	var fleet: Array = session.get("fleet")
	var flagship_index := int(session.get("flagship_index"))
	for index in range(fleet.size()):
		if index == flagship_index:
			continue
		var ship: Dictionary = fleet[index]
		var consort := NPC_SHIP_SCENE.instantiate() as Node3D
		add_child(consort)
		var record: Dictionary = ship.get("loadout", {}).duplicate(true)
		record["id"] = str(ship.get("id", "consort_%d" % index))
		record["name"] = FleetScript.get_display_name(ship)
		# Fan them out astern so a fleet of three does not stack in one wake.
		var offset := Vector3(5.0 if index % 2 == 0 else -5.0, 0.0, 7.0 + 4.0 * index)
		# Spawn ON station, never on top of the flagship. Two hulls sharing a
		# position get shoved apart by depenetration along the cheapest axis —
		# vertically — and a ship left riding 1.6 units high sails straight over
		# the island, whose collision box is only 1.2 tall.
		var station := player.global_position + player.global_transform.basis.orthonormalized() * offset
		record["start_x"] = station.x
		record["start_z"] = station.z
		record["route"] = []
		consort.call("configure", record)
		consort.set("follow_target", player)
		consort.set("follow_offset", offset)
		consorts.append(consort)


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


func _update_port_availability() -> void:
	port_available = false
	if player == null or port == null:
		return
	port_available = player.global_position.distance_to(port.global_position) <= port_enter_distance


func _get_intercept_range(player_ship: Node3D, npc_ship: Node3D) -> float:
	var player_radius := player_ship.scale.x * intercept_radius_per_scale if player_ship else 0.0
	var npc_radius := npc_ship.scale.x * intercept_radius_per_scale if npc_ship else 0.0
	return intercept_distance + player_radius + npc_radius
