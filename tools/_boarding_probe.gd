extends Node

# Dev tool: loads the real naval battle, lays the enemy alongside, and captures
# the boarding prompt and the duel launching over the live battle scene. Proves
# the overlay works from inside a running world, not just standalone.
#   godot --path . res://tools/_BoardingProbe.tscn ++ --out=C:/some/dir

const BATTLE_SCENE := "res://game/scenes/NavalBattle.tscn"

var out_dir := "res://assets/temporary"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")

	var scene: Node = load(BATTLE_SCENE).instantiate()
	add_child(scene)
	scene.set("auto_return_to_overworld", false)
	await get_tree().create_timer(1.2).timeout

	var player := scene.get_node_or_null("PlayerShip") as Node3D
	var target := scene.get_node_or_null("TargetShip") as Node3D
	var boarding := scene.get_node_or_null("BoardingController")
	target.set("ai_enabled", false)
	target.set("firing_enabled", false)
	target.set("movement_enabled", false)

	# Well out of reach: the prompt should be coaxing you closer.
	target.global_position = player.global_position + Vector3(26.0, 0.0, 6.0)
	await get_tree().create_timer(0.6).timeout
	await _capture("far")

	# Alongside, enemy fresh.
	target.global_position = player.global_position + Vector3(9.0, 0.0, 2.0)
	target.set("velocity", Vector3.ZERO)
	await get_tree().create_timer(0.6).timeout
	await _capture("alongside_fresh")

	# Alongside after a grape-shot mauling: same prompt, weaker deck.
	target.call("apply_crew_damage", float(target.get("crew")) * 0.8)
	target.call("apply_morale_damage", float(target.get("morale")) * 0.75)
	await get_tree().create_timer(0.4).timeout
	await _capture("alongside_broken")

	# Throw the grapples and let the duel take over the battle scene.
	boarding.call("begin_boarding")
	await get_tree().create_timer(0.5).timeout
	await _capture("grappling")
	await get_tree().create_timer(2.2).timeout
	await _capture("duel_over_battle")

	get_tree().quit()


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/boarding_%s.png" % [out_dir, label]
	var error := image.save_png(path)
	print("BoardingProbe saved %s (error=%d)" % [path, error])
