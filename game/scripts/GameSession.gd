extends Node

const OVERWORLD_SCENE_PATH := "res://game/scenes/Overworld.tscn"
const NAVAL_BATTLE_SCENE_PATH := "res://game/scenes/NavalBattle.tscn"

var selected_encounter: Dictionary = {}
var defeated_encounter_ids: Array[String] = []
var last_overworld_player_position: Vector3 = Vector3(-18.0, 0.0, 44.0)
var last_battle_result: String = ""


func start_encounter(encounter: Dictionary, player_position: Vector3) -> void:
	selected_encounter = encounter.duplicate(true)
	last_overworld_player_position = player_position
	last_battle_result = ""
	get_tree().change_scene_to_file(NAVAL_BATTLE_SCENE_PATH)


func finish_battle(result: String) -> void:
	last_battle_result = result
	if result == "enemy_sunk" and not selected_encounter.is_empty():
		var encounter_id := str(selected_encounter.get("id", ""))
		if not encounter_id.is_empty() and not defeated_encounter_ids.has(encounter_id):
			defeated_encounter_ids.append(encounter_id)
	selected_encounter = {}
	get_tree().change_scene_to_file(OVERWORLD_SCENE_PATH)


func get_selected_encounter() -> Dictionary:
	return selected_encounter.duplicate(true)


func is_encounter_defeated(encounter_id: String) -> bool:
	return defeated_encounter_ids.has(encounter_id)
