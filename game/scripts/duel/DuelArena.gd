class_name DuelArena
extends Node3D

# The duel's stage and its only entry point for callers:
#
#   var arena := DuelArenaScript.new()
#   parent.add_child(arena)
#   arena.duel_finished.connect(_on_duel_finished)
#   arena.begin(context)
#
# It is an overlay, not a scene change (docs/design/boarding-duel-brief.md): the
# arena is built far above the caller's world, takes over the camera, pauses the
# tree, and hands everything back when the fight ends. No caller has to
# serialise its world to run a duel.

const DuelControllerScript := preload("res://game/scripts/duel/DuelController.gd")
const DuelContextScript := preload("res://game/scripts/duel/DuelContext.gd")
const DuelFighterScript := preload("res://game/scripts/duel/DuelFighter.gd")
const DuelHudScript := preload("res://game/scripts/duel/DuelHud.gd")
const DuelActionScript := preload("res://game/scripts/duel/DuelAction.gd")
const HUD_THEME := preload("res://game/ui/HudTheme.tres")
const OCEAN_MATERIAL := preload("res://game/materials/StylizedOceanMaterial.tres")
const CARIBBEAN_ENVIRONMENT := preload("res://game/environment/CaribbeanEnvironment.tres")

const DECK_WOOD := Color(0.62, 0.44, 0.26)
const DECK_WOOD_DARK := Color(0.5, 0.34, 0.19)
const HULL_WOOD := Color(0.29, 0.18, 0.1)

# Far enough above the caller's world that nothing in it can appear behind the
# deck; the duel is a separate place, not a corner of the battle.
@export var arena_offset: Vector3 = Vector3(0.0, 900.0, 0.0)
@export var autostart_demo: bool = false
@export var result_hold: float = 2.0

signal duel_finished(result: Dictionary)

var controller: Node
var hud: Control
var context: Dictionary = {}

const CROWD_PER_SIDE := 6
const CROWD_SCALE := 0.62

var _player_fighter: Node3D
var _opponent_fighter: Node3D
# Background brawlers, one cluster per side. They thin out as their side's
# numbers fall, so the melee is something you watch rather than read.
var _crowd: Dictionary = {"player": [], "opponent": []}
var _crowd_timers: Array[float] = []
var _camera: Camera3D
var _previous_camera: Camera3D
var _tree_was_paused: bool = false
var _wave_field_process_mode: int = -1
var _shake: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
# Near side-on so attack heights stay unambiguous, tightened until the two
# fighters own the frame rather than swimming in deck.
var _camera_base: Vector3 = Vector3(0.35, 1.95, 5.0)
var _finish_timer: float = -1.0
var _result: Dictionary = {}
var _selected_weapon: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if autostart_demo:
		begin(_demo_context())


func begin(duel_context: Dictionary) -> void:
	context = DuelContextScript.normalize(duel_context)
	position = arena_offset
	_build_stage()
	_build_fighters()
	_build_camera()
	_build_hud()
	_build_controller()

	_tree_was_paused = get_tree().paused
	get_tree().paused = true
	_hold_ocean_animation()

	# One weapon on offer is not a choice: take it and start. No weapons on offer
	# means the caller already decided, so use what the fighter carries.
	var choices: Array = context.get("weapon_choices", [])
	if choices.size() > 1:
		hud.phase = DuelHudScript.PHASE_WEAPON_SELECT
	elif choices.size() == 1:
		_start_fight(str(choices[0]))
	else:
		_start_fight(str(context.get("player", {}).get("weapon", "longsword")))


func _process(delta: float) -> void:
	if _player_fighter:
		_player_fighter.advance(delta)
	if _opponent_fighter:
		_opponent_fighter.advance(delta)
	_advance_crowd(delta)
	_update_shake(delta)
	if _finish_timer >= 0.0:
		_finish_timer -= delta
		if _finish_timer <= 0.0:
			_close()


func _input(event: InputEvent) -> void:
	if hud == null:
		return
	if hud.phase == DuelHudScript.PHASE_WEAPON_SELECT:
		_handle_weapon_select(event)
		return
	if hud.phase != DuelHudScript.PHASE_FIGHTING or controller == null:
		return
	for action in DuelActionScript.INPUT_ACTIONS:
		if event.is_action_pressed(str(DuelActionScript.INPUT_ACTIONS[action])):
			controller.submit_player_action(action)
			get_viewport().set_input_as_handled()
			return


func _handle_weapon_select(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var choices: Array = context.get("weapon_choices", [])
	var index := -1
	match key.keycode:
		KEY_1, KEY_KP_1:
			index = 0
		KEY_2, KEY_KP_2:
			index = 1
		KEY_3, KEY_KP_3:
			index = 2
		KEY_4, KEY_KP_4:
			index = 3
	if index < 0 or index >= choices.size():
		return
	get_viewport().set_input_as_handled()
	_start_fight(str(choices[index]))


func _start_fight(weapon_id: String) -> void:
	_selected_weapon = weapon_id
	hud.phase = DuelHudScript.PHASE_FIGHTING
	controller.start(weapon_id)


func _build_controller() -> void:
	controller = DuelControllerScript.new()
	controller.name = "DuelController"
	controller.configure(context)
	add_child(controller)
	controller.state_changed.connect(_on_state_changed)
	controller.hit_landed.connect(_on_hit_landed)
	controller.attack_countered.connect(_on_attack_countered)
	controller.taunt_landed.connect(_on_taunt_landed)
	controller.pistol_fired.connect(_on_pistol_fired)
	controller.pistol_spoiled.connect(_on_pistol_spoiled)
	controller.support_changed.connect(_on_support_changed)
	controller.support_surged.connect(func(side: String): hud.flash_support(side))
	controller.support_broken.connect(_on_support_broken)
	controller.duel_finished.connect(_on_duel_finished)
	hud.controller = controller


func _build_stage() -> void:
	var stage := Node3D.new()
	stage.name = "Stage"
	add_child(stage)

	# A solid slab under the planking: without it the seams between planks are
	# see-through slots and the sea shows as blue lines up the deck.
	_box(stage, Vector3(15.4, 0.5, 9.2), Vector3(0.0, -0.42, -0.5), DECK_WOOD_DARK)

	# Planks run fore-and-aft, away from the camera: real deck direction, and the
	# receding lines give the flat stage some depth.
	for index in range(23):
		var plank := _box(stage, Vector3(0.66, 0.36, 9.0), Vector3(-7.04 + index * 0.64, -0.18, -0.5), DECK_WOOD if index % 2 == 0 else DECK_WOOD_DARK)
		plank.name = "Plank%d" % index

	# Bulwark behind the fighters, with a rail cap and gun-port hints.
	_box(stage, Vector3(15.0, 1.05, 0.3), Vector3(0.0, 0.52, -4.75), HULL_WOOD)
	_box(stage, Vector3(15.0, 0.16, 0.5), Vector3(0.0, 1.12, -4.75), Color(0.36, 0.23, 0.13))
	for offset in [-5.2, -1.8, 1.8, 5.2]:
		_box(stage, Vector3(0.9, 0.5, 0.12), Vector3(offset, 0.5, -4.92), Color(0.15, 0.1, 0.06))

	# Mast stub and deck clutter give the eye a sense of scale and place.
	var mast := _cylinder(stage, 0.34, 6.4, Vector3(-4.6, 3.2, -2.4), Color(0.42, 0.29, 0.16))
	mast.name = "Mast"
	_box(stage, Vector3(0.9, 0.9, 0.9), Vector3(5.1, 0.45, -3.1), Color(0.45, 0.31, 0.18))
	_box(stage, Vector3(0.8, 0.7, 0.8), Vector3(6.0, 0.35, -2.6), Color(0.38, 0.26, 0.15))
	_cylinder(stage, 0.42, 0.95, Vector3(4.1, 0.48, -3.4), Color(0.33, 0.22, 0.13))

	# Sea and sky beyond the rail: the fight is unmistakably at sea.
	var sea := MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(400.0, 400.0)
	sea_mesh.subdivide_width = 48
	sea_mesh.subdivide_depth = 48
	sea.mesh = sea_mesh
	sea.position = Vector3(0.0, -1.4, -60.0)
	sea.material_override = OCEAN_MATERIAL
	stage.add_child(sea)

	var sun := DirectionalLight3D.new()
	sun.name = "DuelSun"
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	stage.add_child(sun)

	if get_viewport().find_world_3d().environment == null:
		var world_environment := WorldEnvironment.new()
		world_environment.environment = CARIBBEAN_ENVIRONMENT
		stage.add_child(world_environment)


func _build_fighters() -> void:
	_player_fighter = DuelFighterScript.new()
	_player_fighter.name = "PlayerFighter"
	add_child(_player_fighter)
	_player_fighter.build(context.get("player", {}))
	_player_fighter.position = Vector3(-1.4, 0.0, 0.0)

	_opponent_fighter = DuelFighterScript.new()
	_opponent_fighter.name = "OpponentFighter"
	add_child(_opponent_fighter)
	_opponent_fighter.build(context.get("opponent", {}))
	_opponent_fighter.position = Vector3(1.4, 0.0, 0.0)
	_opponent_fighter.rotation_degrees.y = 180.0
	_build_crowd()


# Two knots of fighters brawling behind the duel. They are the same procedural
# figure at a smaller scale, cycling through poses on their own timers, so the
# deck never looks like two men fighting in an empty ship.
func _build_crowd() -> void:
	if context.get("support", {}).is_empty():
		return
	var looks := {"player": context.get("player", {}), "opponent": context.get("opponent", {})}
	for side in ["player", "opponent"]:
		# Each side's men stand on THEIR side of the deck — behind their own
		# captain — while still facing the enemy. Placement and facing are
		# opposite signs, which is easy to get backwards and looks it.
		var behind := -1.0 if side == "player" else 1.0
		for index in range(CROWD_PER_SIDE):
			var brawler: Node3D = DuelFighterScript.new()
			brawler.name = "%sCrowd%d" % [side, index]
			add_child(brawler)
			brawler.build(looks[side])
			brawler.scale = Vector3.ONE * CROWD_SCALE
			# Set back from the duel and staggered in depth, so the two captains
			# stay the subject and the brawl reads as happening around them.
			var depth := -2.8 - float(index % 3) * 0.72
			var lateral := behind * (2.3 + float(index) * 0.66) + behind * float(index % 2) * 0.4
			brawler.position = Vector3(lateral, 0.0, depth)
			brawler.rotation_degrees.y = 0.0 if side == "player" else 180.0
			_crowd[side].append(brawler)
			_crowd_timers.append(randf() * 1.2)


func _advance_crowd(delta: float) -> void:
	var poses := ["windup", "recover", "evade", "stagger"]
	var actions := ["chop", "thrust", "slash", "parry", "jump", "duck"]
	var timer_index := 0
	for side in ["player", "opponent"]:
		for brawler in _crowd[side]:
			if timer_index >= _crowd_timers.size():
				break
			_crowd_timers[timer_index] -= delta
			if _crowd_timers[timer_index] <= 0.0:
				_crowd_timers[timer_index] = randf_range(0.4, 1.1)
				if brawler.visible:
					brawler.apply_state(poses[randi() % poses.size()], actions[randi() % actions.size()])
			timer_index += 1
			if brawler.visible:
				brawler.advance(delta)


# Thin the cluster to match how many of that side are still standing.
func _on_support_changed(side: String, _count: float, fraction: float) -> void:
	var brawlers: Array = _crowd.get(side, [])
	if brawlers.is_empty():
		return
	var standing := int(ceil(fraction * float(brawlers.size())))
	for index in range(brawlers.size()):
		var brawler: Node3D = brawlers[index]
		if index < standing or not brawler.visible:
			continue
		# One falls: drop him where he stands rather than blinking him out.
		brawler.apply_state("yield", "")
		var tween := create_tween()
		tween.tween_interval(0.45)
		tween.tween_callback(func(): brawler.visible = false)


func _build_camera() -> void:
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "DuelCamera"
	_camera.position = _camera_base
	_camera.fov = 48.0
	add_child(_camera)
	_camera.look_at(global_position + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	_camera.current = true


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DuelHudLayer"
	layer.layer = 12
	add_child(layer)

	hud = DuelHudScript.new()
	hud.name = "DuelHud"
	hud.theme = HUD_THEME
	hud.title = str(context.get("title", "DUEL"))
	hud.subtitle = str(context.get("subtitle", ""))
	hud.weapon_choices = context.get("weapon_choices", [])
	layer.add_child(hud)


func _on_state_changed(side: String, state: String, action: String, _duration: float) -> void:
	var fighter := _fighter_for(side)
	if fighter:
		fighter.apply_state(state, action)


func _on_hit_landed(side: String, action: String, _damage: float, kind: String) -> void:
	var attacker := _fighter_for(side)
	if attacker and action != DuelActionScript.PISTOL:
		attacker.play_strike(action)
	var target_side := "opponent" if side == "player" else "player"
	var target := _fighter_for(target_side)
	if target:
		# Toward the camera and out from the chest: a flash inside the torso box
		# is a flash nobody sees.
		_spawn_flash(target.position + Vector3(_facing(target_side) * 0.2, 1.25, 0.42), Color(0.9, 0.25, 0.16), 0.5)
	_shake = maxf(_shake, 0.18 if kind == DuelControllerScript.HIT_CLEAN else 0.3)

	if side == "player":
		match kind:
			DuelControllerScript.HIT_RIPOSTE:
				hud.flash("RIPOSTE!", Color(0.95, 0.82, 0.34))
			DuelControllerScript.HIT_INTERRUPT:
				hud.flash("BEATEN TO IT!", Color(0.95, 0.82, 0.34))
			DuelControllerScript.HIT_WRONG_EVADE:
				hud.flash("WRONG-FOOTED HIM!", Color(0.95, 0.82, 0.34))
	else:
		match kind:
			DuelControllerScript.HIT_WRONG_EVADE:
				hud.flash("WRONG GUARD!", Color(0.92, 0.36, 0.24))
			DuelControllerScript.HIT_PISTOL:
				hud.flash("HE FIRES!", Color(0.92, 0.36, 0.24))
			_:
				hud.flash("TOUCHED!", Color(0.92, 0.36, 0.24))


func _on_attack_countered(side: String, attack: String, _evasion: String) -> void:
	var attacker := _fighter_for(side)
	if attacker:
		attacker.play_strike(attack)
	_spawn_flash(Vector3(0.0, 1.3, 0.4), Color(1.0, 0.94, 0.6), 0.42)
	_shake = maxf(_shake, 0.12)
	if side == "opponent":
		hud.flash("PARRIED!", Color(0.72, 0.88, 1.0))


func _on_taunt_landed(side: String) -> void:
	if side == "player":
		hud.flash("HE IS RATTLED!", Color(0.95, 0.82, 0.34))
	else:
		hud.flash("HE MOCKS YOU!", Color(0.92, 0.36, 0.24))


func _on_pistol_fired(side: String) -> void:
	var fighter := _fighter_for(side)
	if fighter:
		# At the muzzle: out along the fighter's facing, at the extended off-hand.
		_spawn_flash(fighter.position + Vector3(_facing(side) * 0.82, 1.28, 0.3), Color(1.0, 0.86, 0.45), 0.8)
	_shake = maxf(_shake, 0.42)
	hud.flash("SHOT!" if side == "player" else "HE FIRES!", Color(1.0, 0.86, 0.45))


func _on_pistol_spoiled(side: String) -> void:
	if side == "player":
		hud.flash("SHOT SPOILED!", Color(0.92, 0.36, 0.24))


func _on_support_broken(side: String) -> void:
	if side == "player":
		hud.flash("OUR LADS ARE DOWN!", Color(0.92, 0.36, 0.24))
	else:
		hud.flash("THEIR LINE BREAKS!", Color(0.95, 0.82, 0.34))


func _on_duel_finished(result: Dictionary) -> void:
	_result = result
	hud.phase = DuelHudScript.PHASE_FINISHED
	var by_support := str(result.get("reason", "")) == DuelContextScript.REASON_SUPPORT_LOST
	if str(result.get("outcome", "")) == DuelContextScript.OUTCOME_PLAYER_WIN:
		hud.result_text = "THEY ARE OVERWHELMED!" if by_support else "HE YIELDS!"
		hud.result_color = Color(0.95, 0.82, 0.34)
	elif str(result.get("outcome", "")) == DuelContextScript.OUTCOME_PLAYER_LOSS:
		hud.result_text = "YOUR BOARDERS ARE CUT DOWN" if by_support else "YOU ARE CUT DOWN"
		hud.result_color = Color(0.92, 0.28, 0.2)
	else:
		hud.result_text = "THE FIGHT BREAKS OFF"
		hud.result_color = HudStyle.PARCHMENT
	_finish_timer = result_hold


func _close() -> void:
	_finish_timer = -1.0
	get_tree().paused = _tree_was_paused
	_release_ocean_animation()
	if _previous_camera and is_instance_valid(_previous_camera):
		_previous_camera.current = true
	duel_finished.emit(_result)
	queue_free()


# The battle world stays frozen, but the sea behind the duel should not: the
# wave field only advances a shader uniform, so letting it run costs nothing.
func _hold_ocean_animation() -> void:
	var wave_field := get_node_or_null("/root/OceanWaveField")
	if wave_field:
		_wave_field_process_mode = wave_field.process_mode
		wave_field.process_mode = Node.PROCESS_MODE_ALWAYS


func _release_ocean_animation() -> void:
	var wave_field := get_node_or_null("/root/OceanWaveField")
	if wave_field and _wave_field_process_mode >= 0:
		wave_field.process_mode = _wave_field_process_mode


func _update_shake(delta: float) -> void:
	if _camera == null:
		return
	_shake = maxf(0.0, _shake - delta * 1.9)
	if _shake <= 0.0:
		_shake_offset = _shake_offset.lerp(Vector3.ZERO, clampf(delta * 12.0, 0.0, 1.0))
	else:
		_shake_offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.14
	_camera.position = _camera_base + _shake_offset


func _spawn_flash(at: Vector3, color: Color, scale_size: float) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = material
	flash.position = at
	flash.scale = Vector3.ONE * scale_size
	add_child(flash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * scale_size * 2.4, 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.24)
	tween.chain().tween_callback(flash.queue_free)


# Which way a fighter is turned: the player faces +X, the opponent is the same
# figure rotated to face back at them.
func _facing(side: String) -> float:
	return 1.0 if side == "player" else -1.0


func _fighter_for(side: String) -> Node3D:
	return _player_fighter if side == "player" else _opponent_fighter


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	parent.add_child(instance)
	return instance


# A self-contained fight for running the scene straight from the editor.
func _demo_context() -> Dictionary:
	return DuelContextScript.create({
		"title": "PRACTICE BOUT",
		"subtitle": "Deck of the Santa Cecilia",
		"player": {"name": "You", "subtitle": "Pirates", "pistol": true, "coat": "3a2416", "accent": "8f1a10", "hat": "bandana"},
		"opponent": DuelContextScript.fighter_from_profile("naval_officer", {"subtitle": "Spain", "pistol": true})
	})
