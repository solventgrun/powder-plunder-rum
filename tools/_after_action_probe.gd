extends Node

# Disposable probe for the after-action screen: stages a captured treasure
# galleon and a sunk trader, screenshots both, and drives the capture case
# through to a confirmed outcome so the fleet result can be read back.
#   godot --path . res://tools/_AfterActionProbe.tscn ++ --out=C:/some/dir

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const FleetScript := preload("res://game/scripts/session/Fleet.gd")

var out_dir := "res://assets/temporary"
var failures: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	var session := get_node_or_null("/root/GameSession")
	var encounters := ContentCatalog.load_overworld_ship_records()
	var galleon := _find(encounters, "spanish_treasure_galleon")
	var trader := _find(encounters, "dutch_trader_west_jamaica")

	# --- She struck her colours: the full set of decisions ------------------
	_seed_fleet(session)
	session.set("battle_report", _report("enemy_captured", galleon, 0.42, 0.61, 38.0))
	var captured := await _show()
	print("Prize hold offered: %s" % str(captured._prize_manifest))
	await _snap("after_1_captured")

	# Take everything on offer, take her guns, keep her as the new flagship.
	for cargo_id in captured._take_sliders:
		captured._take_sliders[cargo_id].value = captured._take_sliders[cargo_id].max_value
	for cannon_id in captured._gun_sliders:
		captured._gun_sliders[cannon_id].value = captured._gun_sliders[cannon_id].max_value
	captured._recruit_slider.value = captured._recruit_slider.max_value
	if captured._repair_slider.max_value > 0:
		captured._repair_slider.value = captured._repair_slider.max_value
	captured._on_fate_selected(captured.FATE_FLAGSHIP)
	await get_tree().process_frame
	await _snap("after_2_everything_taken")
	print("Confirm disabled with everything taken? %s (expected true — she cannot carry it all)" % str(captured._confirm_button.disabled))

	# Back off until she can actually swim.
	for cannon_id in captured._gun_sliders:
		captured._gun_sliders[cannon_id].value = 0
	await get_tree().process_frame
	print("Confirm enabled after dumping the guns? %s" % str(not captured._confirm_button.disabled))
	if captured._confirm_button.disabled:
		failures.append("A hold that fits should still allow making sail.")
	await _snap("after_3_trimmed")

	captured._apply_outcome()
	var fleet: Array = session.get("fleet")
	print("--- fleet after taking her ---")
	for ship in fleet:
		print("  %s: %s, hold %s" % [FleetScript.get_display_name(ship), FleetScript.describe_condition(ship), str(FleetScript.get_manifest(ship))])
	print("flagship index %d of %d" % [int(session.get("flagship_index")), fleet.size()])
	if fleet.size() != 2:
		failures.append("Keeping a prize should leave two ships in the fleet, got %d." % fleet.size())
	if int(session.get("flagship_index")) != 1:
		failures.append("Taking her as your own should shift the flag to her.")
	captured.queue_free()
	await get_tree().process_frame

	# --- She sank: salvage only --------------------------------------------
	_seed_fleet(session)
	session.set("battle_report", _report("enemy_sunk", trader, 0.8, 0.9, 55.0))
	var sunk := await _show()
	print("Salvage offered from a sunk trader: %s (she carried %s)" % [str(sunk._prize_manifest), str(trader.get("cargo"))])
	if sunk._gun_sliders.size() > 0:
		failures.append("A sunk ship should not be offering her guns.")
	await _snap("after_4_sunk")
	sunk.queue_free()
	await get_tree().process_frame

	# --- You lost her -------------------------------------------------------
	_seed_fleet(session)
	session.set("battle_report", _report("player_sunk", trader, 0.0, 0.3, 4.0))
	var lost := await _show()
	await _snap("after_5_lost")
	lost._apply_outcome()
	print("Fleet after losing your only ship: %d" % (session.get("fleet") as Array).size())
	if (session.get("fleet") as Array).size() != 0:
		failures.append("Losing your only ship should empty the fleet.")

	if failures.is_empty():
		print("AfterActionProbe passed.")
	else:
		for failure in failures:
			print("AfterActionProbe FAILED: %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _seed_fleet(session: Node) -> void:
	session.set("practice_mode", false)
	session.set("fleet", FleetScript.starting_fleet())
	session.set("flagship_index", 0)


func _report(result: String, enemy: Dictionary, hull: float, sail: float, crew: float) -> Dictionary:
	return {
		"result": result,
		"player": {
			"hull_fraction": hull,
			"sail_fraction": sail,
			"crew": crew,
			"morale": 46.0,
			"mast_broken": false,
			"disabled_cannons": {"port": 2, "starboard": 0},
			"disabled_gun_ports": {"port": 1, "starboard": 0}
		},
		"enemy": {
			"hull_fraction": 0.1,
			"sail_fraction": 0.2,
			"crew": 60.0,
			"morale": 5.0,
			"mast_broken": true,
			"disabled_cannons": {"port": 0, "starboard": 0},
			"disabled_gun_ports": {"port": 0, "starboard": 0}
		},
		"enemy_loadout": enemy.duplicate(true),
		"enemy_manifest": enemy.get("cargo", {}).duplicate(),
		"enemy_name": str(enemy.get("name", "Prize"))
	}


func _show() -> Node:
	var scene: Node = (load("res://game/scenes/AfterAction.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	return scene


func _find(records: Array[Dictionary], id: String) -> Dictionary:
	for record in records:
		if str(record.get("id", "")) == id:
			return record
	return {}


func _snap(prefix: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("AfterActionProbe saved %s/%s.png (error=%d)" % [out_dir, prefix, image.save_png("%s/%s.png" % [out_dir, prefix])])
