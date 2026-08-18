extends Node

# Disposable faction-livery probe: spawns lineups of bare ships (builder-only,
# no controllers) inside the battle environment, hides their flags, and shoots
# the proposal's recognition test — can you name the faction at gameplay
# distance before the flag is visible? Run windowed (rendering required):
#   godot --path . res://tools/_LiveryProbe.tscn ++ --out=C:/some/dir

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const ShipVisualBuilderScript := preload("res://game/scripts/visuals/ShipVisualBuilder.gd")

var out_dir := "res://assets/temporary"
var camera: Camera3D

# The proposal's contrast lineup (pirate conversion deferred: the pirate slot
# shows the class-scheme default the other factions recolor away from).
const LINEUP_MIXED := [
	["galleon", "spain"],
	["frigate", "england"],
	["frigate", "france"],
	["brig", "dutch"],
	["sloop", "pirates"],
]
const FACTION_ORDER := ["spain", "england", "france", "dutch", "pirates"]
const CLASS_ROWS := ["galleon", "frigate", "brig", "sloop"]
const SPACING := 16.0

# Figurehead review (--figurehead). Model-space point on the French frigate's
# sea-nymph carving; _spawn_ship's scale and quarter-turn are applied via the
# ship transform, so this stays in authoring coordinates.
const FIGUREHEAD_LOCAL := Vector3(0.0, 0.95, -2.95)
# The last rung is the real battle-camera distance: NavalBattle.tscn parks the
# camera at (0, 18, 16), i.e. ~24 units out. Everything nearer is a cinematic
# or boarding-range look, so the ladder shows where carved detail stops paying.
const FIGUREHEAD_DISTANCES := [2.5, 5.0, 12.0, 24.0]


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
	# Park the battle AI so the lineup shots stay clean.
	var target := scene.get_node_or_null("TargetShip")
	if target:
		target.set("ai_enabled", false)
		target.set("movement_enabled", false)
		target.set("firing_enabled", false)
	await get_tree().create_timer(1.5).timeout

	camera = Camera3D.new()
	add_child(camera)
	camera.make_current()
	if OS.get_cmdline_user_args().has("--figurehead"):
		await _figurehead_ladder()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--pilot-pairs"):
		await _pilot_pair("french_frigate_vs_standard", ["frigate", "england"], ["frigate", "france"], Vector3(-32.0, 0.0, -54.0))
		await _pilot_pair("dutch_brig_vs_standard", ["brig", "england"], ["brig", "dutch"], Vector3(32.0, 0.0, -54.0))
		get_tree().quit()
		return

	var mixed_center := Vector3(-80.0, 0.0, -80.0)
	var mixed_ships := _spawn_lineup(LINEUP_MIXED, mixed_center)
	await get_tree().create_timer(0.8).timeout

	await _wide_shot("livery_1_mixed_lineup", mixed_center)
	for index in range(mixed_ships.size()):
		var entry: Array = LINEUP_MIXED[index]
		await _ship_shot("livery_2%s_%s_%s" % [char(97 + index), entry[1], entry[0]], mixed_ships[index])
	# One class row at a time on the same known-good patch of ocean (formula
	# placement sailed rows off the plane edge), spacing and camera pulled in
	# per class so a sloop row fills the frame like a galleon row.
	var row_center := Vector3(80.0, 0.0, -60.0)
	for row in range(CLASS_ROWS.size()):
		var ship_class: String = CLASS_ROWS[row]
		var row_ships: Array[Node3D] = []
		var row_spacing := 0.0
		for index in range(FACTION_ORDER.size()):
			var ship := _spawn_ship(ship_class, FACTION_ORDER[index], row_center)
			if row_spacing == 0.0:
				row_spacing = 8.0 * ship.scale.x
			ship.position = row_center + Vector3((index - 2) * row_spacing, 0.5, 0.0)
			row_ships.append(ship)
		await get_tree().create_timer(0.5).timeout
		var span := 4.0 * row_spacing
		camera.global_position = row_center + Vector3(0.0, span * 0.5, span * 0.62)
		camera.look_at(row_center + Vector3.UP * 2.0)
		await _snap("livery_3%s_%s_row" % [char(97 + row), ship_class])
		for ship in row_ships:
			ship.queue_free()
		await get_tree().process_frame
	for index in range(mixed_ships.size()):
		var entry: Array = LINEUP_MIXED[index]
		await _close_shot("livery_4%s_%s_%s_bow" % [char(97 + index), entry[1], entry[0]], mixed_ships[index], -1.0)
		await _close_shot("livery_5%s_%s_%s_stern" % [char(97 + index), entry[1], entry[0]], mixed_ships[index], 1.0)
	# The player sails a pirate frigate — close-ups of that exact pairing.
	var player_look := _spawn_ship("frigate", "pirates", row_center)
	await get_tree().create_timer(0.5).timeout
	await _close_shot("livery_6_pirate_frigate_bow", player_look, -1.0)
	await _close_shot("livery_7_pirate_frigate_stern", player_look, 1.0)
	get_tree().quit()


func _spawn_lineup(lineup: Array, center: Vector3) -> Array[Node3D]:
	var ships: Array[Node3D] = []
	var offset := -(lineup.size() - 1) * 0.5 * SPACING
	for index in range(lineup.size()):
		var entry: Array = lineup[index]
		ships.append(_spawn_ship(str(entry[0]), str(entry[1]), center + Vector3(offset + index * SPACING, 0.0, 0.0)))
	return ships


func _spawn_ship(ship_type: String, faction: String, position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%s" % [faction, ship_type]
	add_child(root)
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	root.add_child(visual_root)
	var builder := Node3D.new()
	builder.name = "ShipVisualBuilder"
	builder.set_script(ShipVisualBuilderScript)
	visual_root.add_child(builder)

	var record := {
		"ship_type": ship_type,
		"faction": faction,
		"visual_variant": "",
		"modifications": [],
		"broadsides": {},
		"cargo_weight": 0.0,
	}
	var stats: Resource = ContentCatalog.build_ship_stats(record, ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
	root.scale = Vector3.ONE * float(stats.get("visual_scale"))
	root.position = position + Vector3(0.0, 0.5, 0.0)
	# Quarter turn so the camera reads hull side + deck, the gameplay view.
	root.rotation_degrees = Vector3(0.0, 32.0, 0.0)
	builder.call("apply_visuals", record, stats)
	# The recognition test runs with flags off (proposal requirement).
	for flag in builder.get("flag_nodes"):
		if flag is Node3D:
			(flag as Node3D).visible = false
	print("LiveryProbe spawned %s %s" % [faction, ship_type])
	return root


func _wide_shot(prefix: String, center: Vector3) -> void:
	camera.global_position = center + Vector3(0.0, 30.0, 36.0)
	camera.look_at(center + Vector3(0.0, 2.0, 0.0))
	await _snap(prefix)


# Figurehead review: the same carving at four distances, so detail work can be
# judged against the distance it actually has to survive. Each rung also saves
# a native-pixel crop (see _snap_with_inset) because at battle range the whole
# figure is only a dozen-odd pixels tall and a scaled screenshot lies about it.
func _figurehead_ladder() -> void:
	var ship := _spawn_ship("frigate", "france", Vector3(0.0, 0.0, -70.0))
	await get_tree().create_timer(0.8).timeout
	var basis := ship.global_transform.basis.orthonormalized()
	var focus: Vector3 = ship.global_transform * FIGUREHEAD_LOCAL
	# Bow quarter: ahead of her, a little to starboard and above — the angle a
	# player closing on the bow actually gets.
	var direction := (basis * Vector3(0.55, 0.28, -1.0)).normalized()
	for index in range(FIGUREHEAD_DISTANCES.size()):
		var distance: float = FIGUREHEAD_DISTANCES[index]
		camera.global_position = focus + direction * distance
		camera.look_at(focus)
		var label := ("%.1f" % distance).replace(".", "p")
		await _snap_with_inset("figurehead_%d_at_%s" % [index + 1, label], focus)
	ship.queue_free()


# Focused Phase 2 review: standard-geometry comparison on the left, pilot on
# the right. Flags remain hidden because _spawn_ship owns that rule.
func _pilot_pair(prefix: String, standard: Array, pilot: Array, center: Vector3) -> void:
	var left := _spawn_ship(str(standard[0]), str(standard[1]), center + Vector3(-3.6, 0.0, 0.0))
	var right := _spawn_ship(str(pilot[0]), str(pilot[1]), center + Vector3(3.6, 0.0, 0.0))
	await get_tree().create_timer(0.8).timeout
	camera.global_position = center + Vector3(0.0, 6.8, 10.5)
	camera.look_at(center + Vector3.UP * 1.4)
	await _snap(prefix)
	left.queue_free()
	right.queue_free()


# The follow camera's own gameplay offset, so readability is judged at the
# distance the player actually sees.
func _ship_shot(prefix: String, ship: Node3D) -> void:
	camera.global_position = ship.global_position + Vector3(0.0, 18.0, 16.0)
	camera.look_at(ship.global_position)
	await _snap(prefix)


# Hero-style close-up, offsets scaled by the ship's visual scale so the sloop
# gets as tight a frame as the galleon. along_z -1 = bow quarter, +1 = stern.
func _close_shot(prefix: String, ship: Node3D, along_z: float) -> void:
	var s := ship.scale.x
	var aft: Vector3 = ship.global_transform.basis.z.normalized()
	var right: Vector3 = ship.global_transform.basis.x.normalized()
	camera.global_position = ship.global_position \
		+ aft * along_z * 4.2 * s + right * 3.0 * s + Vector3.UP * (1.6 * s + 0.8)
	camera.look_at(ship.global_position + Vector3.UP * 1.1 * s)
	await _snap(prefix)


# Saves the frame plus a magnified crop of the untouched pixels around a world
# point. Nearest-neighbour on purpose: smooth upscaling invents detail that the
# player never receives, which is the exact question this probe answers.
func _snap_with_inset(prefix: String, focus: Vector3) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("LiveryProbe saved %s/%s.png (error=%d)" % [out_dir, prefix, image.save_png("%s/%s.png" % [out_dir, prefix])])
	# Size the crop from the projection, not a fixed pixel count, so every rung
	# frames the same patch of world around the carving; a fixed box swallows
	# the whole ship at battle range and the figurehead vanishes in it.
	var at := camera.unproject_position(focus)
	var scale_probe := camera.unproject_position(focus + Vector3.UP)
	var pixels_per_unit: float = maxf(absf(scale_probe.y - at.y), 0.001)
	var box := int(clamp(pixels_per_unit * 1.6, 24.0, 420.0))
	var x := int(clamp(at.x - box * 0.5, 0.0, float(image.get_width() - box)))
	var y := int(clamp(at.y - box * 0.5, 0.0, float(image.get_height() - box)))
	var region := image.get_region(Rect2i(x, y, box, box))
	region.resize(720, 720, Image.INTERPOLATE_NEAREST)
	print("LiveryProbe saved %s/%s_pixels.png (error=%d)" % [out_dir, prefix, region.save_png("%s/%s_pixels.png" % [out_dir, prefix])])


func _snap(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, prefix]
	print("LiveryProbe saved %s (error=%d)" % [path, image.save_png(path)])
