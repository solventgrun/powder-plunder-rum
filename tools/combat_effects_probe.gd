extends Node3D

# Dev tool: fires cannonballs across the camera on a loop so ScreenshotProbe
# can catch combat effects (smoke trails, splashes, later muzzle/impact work)
# mid-flight. Not part of any game scene.
#   godot --path . res://tools/ScreenshotProbe.tscn ++ --scene=res://tools/CombatEffectsProbe.tscn --prefix=trail --out=C:/some/dir

const CannonballScene := preload("res://game/scenes/Cannonball.tscn")
const MuzzleFlashScene := preload("res://game/scenes/MuzzleFlash.tscn")

var elapsed := 0.0
var next_shot_at := 0.5


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= next_shot_at:
		next_shot_at += 0.9
		var muzzle := Vector3(-14.0, 1.4, 0.0)
		var ball := CannonballScene.instantiate() as Node3D
		add_child(ball)
		ball.global_position = muzzle
		ball.set("direction", Vector3.RIGHT)
		ball.set("speed", 22.0)
		ball.set("remaining_range", 22.0)
		var flash := MuzzleFlashScene.instantiate() as Node3D
		add_child(flash)
		flash.global_position = muzzle
