extends Node

# Disposable HUD-layout probe: loads battle and overworld with the UI VISIBLE
# and screenshots each (2026-08-17: debug column moved right + shrunk, HUD
# compass/status moved left). Run windowed:
#   godot --path . res://tools/_HudProbe.tscn ++ --out=C:/some/dir

var out_dir := "res://assets/temporary"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")

	var battle := (load("res://game/scenes/NavalBattle.tscn") as PackedScene).instantiate()
	battle.set("auto_return_to_overworld", false)
	add_child(battle)
	await get_tree().create_timer(2.5).timeout
	await _snap("hud_1_battle")
	battle.queue_free()
	await get_tree().process_frame

	var overworld := (load("res://game/scenes/Overworld.tscn") as PackedScene).instantiate()
	add_child(overworld)
	await get_tree().create_timer(2.5).timeout
	await _snap("hud_2_overworld")
	get_tree().quit()


func _snap(prefix: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, prefix]
	print("HudProbe saved %s (error=%d)" % [path, image.save_png(path)])
