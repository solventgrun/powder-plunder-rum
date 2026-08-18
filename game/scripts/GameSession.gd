extends Node

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")

const MAIN_MENU_SCENE_PATH := "res://game/scenes/MainMenu.tscn"
const OVERWORLD_SCENE_PATH := "res://game/scenes/Overworld.tscn"
const NAVAL_BATTLE_SCENE_PATH := "res://game/scenes/NavalBattle.tscn"
const PRACTICE_SETUP_SCENE_PATH := "res://game/scenes/PracticeSetup.tscn"
const AFTER_ACTION_SCENE_PATH := "res://game/scenes/AfterAction.tscn"
const PORT_MENU_SCENE_PATH := "res://game/scenes/PortMenu.tscn"
const PORT_SELL_CARGO_SCENE_PATH := "res://game/scenes/PortSellCargo.tscn"
const PORT_BUY_PROVISIONS_SCENE_PATH := "res://game/scenes/PortBuyProvisions.tscn"
const PORT_REPAIR_SCENE_PATH := "res://game/scenes/PortRepair.tscn"
const PORT_HIRE_CREW_SCENE_PATH := "res://game/scenes/PortHireCrew.tscn"
const FLEET_MANAGEMENT_SCENE_PATH := "res://game/scenes/FleetManagement.tscn"
const OVERWORLD_START_POSITION := Vector3(-18.0, 0.0, 44.0)

var selected_encounter: Dictionary = {}
var defeated_encounter_ids: Array[String] = []
var last_overworld_player_position: Vector3 = OVERWORLD_START_POSITION
var last_battle_result: String = ""
# The game-wide difficulty level (`data/difficulty/difficulty_levels.yaml`),
# chosen once when a new game is created and never per encounter. Sword fights
# read it today; naval combat, land battles, and overworld spawning are expected
# to read their own sections of the same level. Systems should go through
# `GameDifficulty` rather than reaching in here directly.
var game_difficulty: String = "normal"

# The player's ships. The one at `flagship_index` is the one they sail; the rest
# follow as consorts. The player was never meant to be married to one hull
# (user directive 2026-08-17) — see game/scripts/session/Fleet.gd.
var fleet: Array[Dictionary] = []
var flagship_index: int = 0
var gold: int = 0
var fleet_screen_return: String = "overworld"

# What just happened in a battle, assembled by NavalBattle and read by the
# after-action screen. Empty outside that handoff.
var battle_report: Dictionary = {}

# Practice battles (main menu -> Practice Naval Combat) are a testing harness,
# not part of the campaign: both ships are built on the setup screen instead of
# the player coming from the fleet and the enemy from an overworld encounter.
# `practice_mode` is also what decides where a finished battle returns to.
var practice_mode: bool = false
var player_ship_override: Dictionary = {}
var practice_setup_state: Dictionary = {}


func _ready() -> void:
	if fleet.is_empty():
		fleet = FleetScript.starting_fleet()


func start_new_game() -> void:
	practice_mode = false
	player_ship_override = {}
	selected_encounter = {}
	battle_report = {}
	defeated_encounter_ids.clear()
	last_battle_result = ""
	last_overworld_player_position = OVERWORLD_START_POSITION
	fleet = FleetScript.starting_fleet()
	flagship_index = 0
	gold = 0
	fleet_screen_return = "overworld"
	get_tree().change_scene_to_file(OVERWORLD_SCENE_PATH)


func open_practice_setup() -> void:
	practice_mode = true
	selected_encounter = {}
	get_tree().change_scene_to_file(PRACTICE_SETUP_SCENE_PATH)


func start_practice_battle(player_record: Dictionary, enemy_record: Dictionary) -> void:
	practice_mode = true
	player_ship_override = player_record.duplicate(true)
	selected_encounter = enemy_record.duplicate(true)
	last_battle_result = ""
	battle_report = {}
	get_tree().change_scene_to_file(NAVAL_BATTLE_SCENE_PATH)


func return_to_main_menu() -> void:
	practice_mode = false
	player_ship_override = {}
	selected_encounter = {}
	battle_report = {}
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func start_encounter(encounter: Dictionary, player_position: Vector3) -> void:
	selected_encounter = encounter.duplicate(true)
	last_overworld_player_position = player_position
	last_battle_result = ""
	battle_report = {}
	get_tree().change_scene_to_file(NAVAL_BATTLE_SCENE_PATH)


# Every battle now ends at the after-action screen rather than snapping back to
# the overworld: what a fight cost and what it won is the point of fighting it.
func finish_battle(result: String, report: Dictionary = {}) -> void:
	last_battle_result = result
	battle_report = report.duplicate(true)
	battle_report["result"] = result
	get_tree().change_scene_to_file(AFTER_ACTION_SCENE_PATH)


# Called by the after-action screen once the player has finished deciding.
func leave_after_action() -> void:
	battle_report = {}
	if practice_mode:
		selected_encounter = {}
		get_tree().change_scene_to_file(PRACTICE_SETUP_SCENE_PATH)
		return
	if not selected_encounter.is_empty() and last_battle_result in ["enemy_sunk", "enemy_captured"]:
		var encounter_id := str(selected_encounter.get("id", ""))
		if not encounter_id.is_empty() and not defeated_encounter_ids.has(encounter_id):
			defeated_encounter_ids.append(encounter_id)
	selected_encounter = {}
	if fleet.is_empty():
		# Nothing left to sail. The campaign is over; the menu is the only way on.
		return_to_main_menu()
		return
	get_tree().change_scene_to_file(OVERWORLD_SCENE_PATH)


func abandon_battle() -> void:
	# Escaping out of a practice battle should not read as a defeat; it is the
	# tester deciding this matchup has told them what they wanted to know.
	last_battle_result = "abandoned"
	selected_encounter = {}
	battle_report = {}
	get_tree().change_scene_to_file(PRACTICE_SETUP_SCENE_PATH if practice_mode else OVERWORLD_SCENE_PATH)


func open_port(player_position: Vector3) -> void:
	practice_mode = false
	last_overworld_player_position = player_position
	fleet_screen_return = "port"
	get_tree().change_scene_to_file(PORT_MENU_SCENE_PATH)


func leave_port() -> void:
	fleet_screen_return = "overworld"
	get_tree().change_scene_to_file(OVERWORLD_SCENE_PATH)


func open_port_sell_cargo() -> void:
	get_tree().change_scene_to_file(PORT_SELL_CARGO_SCENE_PATH)


func open_port_buy_provisions() -> void:
	get_tree().change_scene_to_file(PORT_BUY_PROVISIONS_SCENE_PATH)


func open_port_repair() -> void:
	get_tree().change_scene_to_file(PORT_REPAIR_SCENE_PATH)


func open_port_hire_crew() -> void:
	get_tree().change_scene_to_file(PORT_HIRE_CREW_SCENE_PATH)


func return_to_port_menu() -> void:
	fleet_screen_return = "port"
	get_tree().change_scene_to_file(PORT_MENU_SCENE_PATH)


func open_fleet_management(from_port: bool, player_position: Vector3 = OVERWORLD_START_POSITION) -> void:
	if not from_port:
		last_overworld_player_position = player_position
	fleet_screen_return = "port" if from_port else "overworld"
	get_tree().change_scene_to_file(FLEET_MANAGEMENT_SCENE_PATH)


func leave_fleet_management() -> void:
	if fleet_screen_return == "port":
		return_to_port_menu()
	else:
		get_tree().change_scene_to_file(OVERWORLD_SCENE_PATH)


func get_selected_encounter() -> Dictionary:
	return selected_encounter.duplicate(true)


func get_flagship() -> Dictionary:
	if practice_mode and not player_ship_override.is_empty():
		return FleetScript.make_ship(player_ship_override, "", "practice")
	if fleet.is_empty():
		return {}
	return fleet[clampi(flagship_index, 0, fleet.size() - 1)]


func get_player_ship_record() -> Dictionary:
	if practice_mode and not player_ship_override.is_empty():
		return player_ship_override.duplicate(true)
	var flagship := get_flagship()
	if flagship.is_empty():
		return ContentCatalog.load_player_ship_record()
	return flagship.get("loadout", {}).duplicate(true)


# The state the flagship should sail into her next battle carrying. Practice
# battles always start fresh — a testing harness that remembered the last
# thrashing would make every comparison a different fight.
func get_player_ship_condition() -> Dictionary:
	if practice_mode:
		return {}
	var flagship := get_flagship()
	return flagship.get("condition", {}).duplicate(true) if not flagship.is_empty() else {}


func set_flagship_index(index: int) -> void:
	flagship_index = clampi(index, 0, maxi(0, fleet.size() - 1))


func add_prize(ship: Dictionary) -> void:
	fleet.append(ship)


func remove_ship(index: int) -> void:
	if index < 0 or index >= fleet.size():
		return
	fleet.remove_at(index)
	flagship_index = clampi(flagship_index, 0, maxi(0, fleet.size() - 1))


func is_encounter_defeated(encounter_id: String) -> bool:
	return defeated_encounter_ids.has(encounter_id)
