extends Node

# Disposable launcher for the front-end flow driver. Run windowed:
#   godot --path . res://tools/_FlowProbe.tscn ++ --out=C:/some/dir

const FlowDriverScript := preload("res://tools/_flow_driver.gd")


func _ready() -> void:
	var out_dir := "res://assets/temporary"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")

	# Parented to the root, not to this scene, so changing scenes does not free
	# the thing doing the changing. Deferred because the root is still setting
	# up its children while this scene's _ready runs.
	var driver: Node = FlowDriverScript.new()
	driver.name = "FlowDriver"
	driver.set("out_dir", out_dir)
	get_tree().root.add_child.call_deferred(driver)
