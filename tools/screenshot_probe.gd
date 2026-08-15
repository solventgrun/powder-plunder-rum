extends Node

# Dev tool: loads a scene, lets it run, saves viewport screenshots, quits.
# Run windowed (not --headless; the viewport must actually render):
#   godot --path . res://tools/ScreenshotProbe.tscn ++ --scene=res://game/scenes/Overworld.tscn --prefix=overworld --out=C:/some/dir
# Defaults: NavalBattle, prefix "shot", writes into res://assets/temporary.

var target_scene := "res://game/scenes/NavalBattle.tscn"
var out_prefix := "shot"
var out_dir := "res://assets/temporary"
var settle_seconds := 4.0
var shot_count := 3
var shot_interval := 0.8


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			target_scene = arg.trim_prefix("--scene=")
		elif arg.begins_with("--prefix="):
			out_prefix = arg.trim_prefix("--prefix=")
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	var packed: PackedScene = load(target_scene)
	if packed == null:
		push_error("ScreenshotProbe could not load %s" % target_scene)
		get_tree().quit(1)
		return
	add_child(packed.instantiate())
	await get_tree().create_timer(settle_seconds).timeout
	for index in range(shot_count):
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s_%d.png" % [out_dir, out_prefix, index + 1]
		var error := image.save_png(path)
		print("ScreenshotProbe saved %s (error=%d)" % [path, error])
		await get_tree().create_timer(shot_interval).timeout
	get_tree().quit()
