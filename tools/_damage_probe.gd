extends Node

# Disposable probe for the Tier 3 damage states: drives the target galleon's
# combat component directly and photographs listing, fire severities, and
# sail tatter. Run windowed (rendering required):
#   godot --path . res://tools/_DamageProbe.tscn ++ --out=C:/some/dir

var out_dir := "res://assets/temporary"
var camera: Camera3D
var ship: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	var packed: PackedScene = load("res://game/scenes/NavalBattle.tscn")
	var scene := packed.instantiate()
	scene.set("auto_return_to_overworld", false)
	add_child(scene)
	for child in scene.get_children():
		if child is CanvasLayer or child is Control:
			child.set("visible", false)
	await get_tree().create_timer(2.0).timeout

	camera = Camera3D.new()
	add_child(camera)
	camera.make_current()
	ship = scene.get_node_or_null("TargetShip")
	var combat: Node = ship.get_node_or_null("ShipCombatComponent")

	await _shot("dmg_1_baseline", 0.5)

	combat.call("apply_hull_damage", float(combat.get("max_hull")) * 0.7)
	_defuse(combat)
	await _shot("dmg_2_listing", 4.0)

	combat.call("_apply_burning", "medium")
	_defuse(combat)
	await _shot("dmg_3_fire_medium", 2.0)

	combat.call("_apply_burning", "large")
	_defuse(combat)
	await _shot("dmg_4_fire_large", 2.0)

	combat.call("apply_sail_damage", float(combat.get("max_sail")) * 0.3)
	await _shot("dmg_5a_sails_30", 1.0)

	combat.call("apply_sail_damage", float(combat.get("max_sail")) * 0.3)
	await _shot("dmg_5b_sails_60", 1.0)

	combat.call("apply_sail_damage", float(combat.get("max_sail")) * 0.25)
	await _shot("dmg_5b2_sails_85", 1.0)

	# Zeroing sail trips break_mast: the assemblies topple staggered
	# (0.15s + 0.45s per mast, 1.15s fall + 0.3s settle each).
	combat.call("apply_sail_damage", 9999.0)
	await _shot("dmg_5c_mast_falling", 0.9)
	await _shot("dmg_5d_mast_second", 0.8)
	await _shot("dmg_5e_masts_down", 1.6)

	combat.call("_explode")
	await _shot("dmg_6_explosion_flash", 0.12)
	await _shot("dmg_7_explosion_smoke", 0.45)
	await _shot("dmg_8_shockwave", 0.5)
	await _shot("dmg_9_sinking_mid", 1.2)
	await _shot("dmg_10_wreck", 2.2)
	get_tree().quit()


# The probe must not lose its subject: no random growth, explosion, or
# burn-down while framing shots (the smoke test's hard-won lesson).
func _defuse(combat: Node) -> void:
	combat.set("burning_magazine_explosion_chance_per_second", 0.0)
	combat.set("burning_growth_chance_per_second", 0.0)
	combat.set("burning_hull_damage_per_second", 0.0)


func _shot(prefix: String, settle: float) -> void:
	await get_tree().create_timer(settle).timeout
	var stern: Vector3 = ship.global_position + ship.global_transform.basis.z.normalized() * 9.0
	camera.global_position = stern + ship.global_transform.basis.x.normalized() * 5.0 + Vector3.UP * 4.5
	camera.look_at(ship.global_position + Vector3.UP * 2.6)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, prefix]
	print("DamageProbe saved %s (error=%d)" % [path, image.save_png(path)])
