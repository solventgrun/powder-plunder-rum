extends Node

# Dev tool: drives the sword duel through specific moments and screenshots each
# one, so poses, tells, and HUD states can be judged by looking at them rather
# than reasoned about. Run windowed (the viewport must render):
#   godot --path . res://tools/_DuelProbe.tscn ++ --out=C:/some/dir

const DuelArenaScript := preload("res://game/scripts/duel/DuelArena.gd")
const DuelContextScript := preload("res://game/scripts/duel/DuelContext.gd")
const DuelActionScript := preload("res://game/scripts/duel/DuelAction.gd")

var out_dir := "res://assets/temporary"
var arena: Node3D
var controller: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")

	arena = DuelArenaScript.new()
	add_child(arena)
	arena.begin(DuelContextScript.create({
		"title": "BOARDING ACTION",
		"subtitle": "Santa Cecilia",
		"weapon_choices": ["longsword"],
		"player": {"name": "You", "subtitle": "Pirates", "pistol": true, "coat": "3a2416", "accent": "8f1a10", "hat": "bandana"},
		"opponent": DuelContextScript.fighter_from_profile("naval_officer", {"subtitle": "Spain", "pistol": true}),
		"support": {
			"player": {"label": "Pirates", "count": 44.0, "strength": 1.0},
			"opponent": {"label": "Spain", "count": 58.0, "strength": 1.1}
		}
	}))
	controller = arena.controller
	controller.opponent_brain_enabled = false

	await get_tree().create_timer(1.6).timeout

	# Guard stance, both fighters composed.
	await _capture("guard")

	# Opponent's wind-up: the tell the whole duel rests on.
	controller.submit_opponent_action(DuelActionScript.CHOP)
	await get_tree().create_timer(0.3).timeout
	await _capture("tell_high")

	# Player answers correctly and the blow is turned.
	controller.submit_player_action(DuelActionScript.DUCK)
	await get_tree().create_timer(0.12).timeout
	await _capture("duck")
	await get_tree().create_timer(0.9).timeout

	# Player's own strike landing on a flat-footed opponent.
	controller.submit_player_action(DuelActionScript.THRUST)
	await get_tree().create_timer(0.62).timeout
	await _capture("thrust_lands")

	await get_tree().create_timer(1.0).timeout
	controller.submit_player_action(DuelActionScript.TAUNT)
	await get_tree().create_timer(0.35).timeout
	await _capture("taunt")

	await get_tree().create_timer(1.2).timeout
	controller.submit_player_action(DuelActionScript.PISTOL)
	await get_tree().create_timer(0.68).timeout
	await _capture("pistol")

	# Finish him, to check the yield pose and the result banner.
	var opponent: Dictionary = controller.get_fighter("opponent")
	opponent["vigor"] = 6.0
	await get_tree().create_timer(1.0).timeout
	controller.submit_player_action(DuelActionScript.CHOP)
	await get_tree().create_timer(1.1).timeout
	await _capture("yield")
	# Past the yield hold, so the result banner is on screen.
	await get_tree().create_timer(1.2).timeout
	await _capture("result")

	get_tree().quit()


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/duel_%s.png" % [out_dir, label]
	var error := image.save_png(path)
	print("DuelProbe saved %s (error=%d)" % [path, error])
