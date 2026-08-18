extends Node

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		failures.append("GameSession autoload is missing.")
	else:
		var encounters := ContentCatalog.load_overworld_ship_records()
		var enemy := _find(encounters, "spanish_treasure_galleon")
		session.set("practice_mode", false)
		session.set("fleet", FleetScript.starting_fleet())
		session.set("flagship_index", 0)
		session.set("battle_report", _report(enemy))

	var packed := load("res://game/scenes/AfterAction.tscn") as PackedScene
	if packed == null:
		failures.append("AfterAction scene did not load.")
	else:
		var scene := packed.instantiate()
		add_child(scene)
		await get_tree().process_frame
		if scene.get("_take_sliders").is_empty():
			failures.append("A captured prize should expose loot sliders.")
		if scene.get("_gun_sliders").is_empty():
			failures.append("A captured prize should expose gun sliders.")
		if scene.get("_recruit_slider") == null:
			failures.append("A captured prize should expose a recruit slider.")
		if scene.get("_slider_value_labels").has("ration"):
			failures.append("Rum rations belong in fleet management, not after-action.")
		scene.queue_free()

	for failure in failures:
		push_error(failure)
	print("AfterActionSliderCheck %s" % ("passed" if failures.is_empty() else "failed"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _find(records: Array[Dictionary], id: String) -> Dictionary:
	for record in records:
		if str(record.get("id", "")) == id:
			return record
	return {}


func _report(enemy: Dictionary) -> Dictionary:
	return {
		"result": "enemy_captured",
		"player": {
			"hull_fraction": 0.65,
			"sail_fraction": 0.75,
			"crew": 42.0,
			"morale": 55.0,
			"mast_broken": false,
			"disabled_cannons": {},
			"disabled_gun_ports": {}
		},
		"enemy": {
			"hull_fraction": 0.25,
			"sail_fraction": 0.2,
			"crew": 36.0,
			"morale": 5.0,
			"mast_broken": true,
			"disabled_cannons": {},
			"disabled_gun_ports": {}
		},
		"enemy_loadout": enemy.duplicate(true),
		"enemy_manifest": enemy.get("cargo", {}).duplicate(),
		"enemy_name": str(enemy.get("name", "Prize"))
	}
