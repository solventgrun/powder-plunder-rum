extends SceneTree

# Disposable bench: what happens to a prize's hold when you keep her rather than
# stripping her. Answers "if I keep her as a consort, do I keep her cargo?"

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var galleon := _encounter("spanish_treasure_galleon")
	print("She carries: %s" % str(galleon.get("cargo")))
	print("Her own free hold: %.0f" % ContentCatalog.get_free_hold(galleon))
	print("")

	await _case("A frigate with no free hold (the shipped loadout)", galleon, {})
	await _case("A lighter frigate with room to spare", galleon, _light_frigate())
	quit(0)


func _case(title: String, galleon: Dictionary, player_override: Dictionary) -> void:
	var session := root.get_node_or_null("GameSession")
	session.set("practice_mode", false)
	var fleet: Array[Dictionary] = FleetScript.starting_fleet()
	if not player_override.is_empty():
		fleet[0]["loadout"] = player_override
	session.set("fleet", fleet)
	session.set("flagship_index", 0)
	session.set("battle_report", _report(galleon))

	var scene: Node = (load("res://game/scenes/AfterAction.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame

	var taken := {}
	for cargo_id in scene.get("_take_sliders"):
		var units := int(scene.get("_take_sliders")[cargo_id].value)
		if units > 0:
			taken[cargo_id] = units

	scene.call("_on_fate_selected", "consort")
	scene.call("_apply_outcome")

	var after: Array = session.get("fleet")
	print("=== %s ===" % title)
	print("  free hold before: %.0f" % ContentCatalog.get_free_hold(fleet[0]["loadout"]))
	print("  you took   : %s" % (str(taken) if not taken.is_empty() else "nothing"))
	print("  your hold  : %s" % str(FleetScript.get_manifest(after[0])))
	if after.size() > 1:
		print("  SHE KEEPS  : %s" % str(FleetScript.get_manifest(after[1])))
		print("  her colours: %s" % str(after[1]["loadout"].get("faction")))
		print("  her crew   : %d (drawn from yours, now %d)" % [FleetScript.get_crew(after[1]), FleetScript.get_crew(after[0])])
	print("")

	root.remove_child(scene)
	scene.free()


func _light_frigate() -> Dictionary:
	var cannons: Array = []
	for _index in range(6):
		cannons.append("long_12_pounder")
	return {
		"ship_type": "frigate", "faction": "pirates", "visual_variant": "worn", "sail_set": "full",
		"crew": 120, "cargo_weight": 0, "modifications": [], "cargo": {},
		"broadsides": {"port": {"cannons": cannons}, "starboard": {"cannons": cannons.duplicate()}}
	}


func _encounter(id: String) -> Dictionary:
	for record in ContentCatalog.load_overworld_ship_records():
		if str(record.get("id", "")) == id:
			return record
	return {}


func _report(enemy: Dictionary) -> Dictionary:
	return {
		"result": "enemy_captured",
		"player": {"hull_fraction": 0.6, "sail_fraction": 0.8, "crew": 110.0, "morale": 70.0, "drunkenness": 0.0,
			"mast_broken": false, "disabled_cannons": {"port": 0, "starboard": 0}, "disabled_gun_ports": {"port": 0, "starboard": 0}},
		"enemy": {"hull_fraction": 0.15, "sail_fraction": 0.3, "crew": 80.0, "morale": 4.0, "drunkenness": 0.0,
			"mast_broken": false, "disabled_cannons": {"port": 0, "starboard": 0}, "disabled_gun_ports": {"port": 0, "starboard": 0}},
		"enemy_loadout": enemy.duplicate(true),
		"enemy_manifest": enemy.get("cargo", {}).duplicate(),
		"enemy_name": str(enemy.get("name", "Prize"))
	}
