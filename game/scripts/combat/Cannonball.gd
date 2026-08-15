extends Area3D
class_name Cannonball

const SplashScene := preload("res://game/scenes/Splash.tscn")
const ImpactFlashScene := preload("res://game/scenes/ImpactFlash.tscn")

@export var fallback_speed: float = 30.0
@export var fallback_range: float = 30.0
@export var fallback_damage: float = 4.0

var direction: Vector3 = Vector3.RIGHT
var speed: float = 30.0
var remaining_range: float = 30.0
var damage: float = 4.0
var status_effects: Dictionary = {}
var ammo_context: Dictionary = {}
var source: Node
var smoke_trail: GPUParticles3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_smoke_trail()


func configure(fire_direction: Vector3, cannon: Resource, ammo: Resource, projectile_source: Node) -> void:
	direction = fire_direction.normalized()
	source = projectile_source
	speed = float(cannon.get("projectile_speed"))
	remaining_range = float(cannon.get("range")) * float(ammo.get("range_multiplier"))
	damage = float(ammo.get("hull_damage"))
	status_effects = ammo.get("status_effects")
	ammo_context = {
		"sail_damage": float(ammo.get("sail_damage")),
		"crew_damage": float(ammo.get("crew_damage")),
		"morale_damage": float(ammo.get("morale_damage")),
		"cannon_disable_chance": float(ammo.get("cannon_disable_chance")),
		"gun_port_disable_chance": float(ammo.get("gun_port_disable_chance"))
	}


func _physics_process(delta: float) -> void:
	var start_position := global_position
	var travel := speed * delta
	var end_position := global_position + direction * travel
	if _try_swept_hit(start_position, end_position):
		return
	global_position = end_position
	remaining_range -= travel
	if remaining_range <= 0.0:
		_spawn_splash()
		_release_smoke_trail()
		queue_free()


func _on_body_entered(body: Node) -> void:
	_hit_body(body)


func _try_swept_hit(start_position: Vector3, end_position: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(start_position, end_position)
	query.exclude = [self.get_rid()]
	if source is CollisionObject3D:
		query.exclude.append((source as CollisionObject3D).get_rid())
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return false

	global_position = result.get("position", end_position)
	var collider: Node = result.get("collider")
	if collider:
		_hit_body(collider)
		return true
	return false


func _hit_body(body: Node) -> void:
	if body == source:
		return
	if body.has_method("apply_projectile_hit"):
		body.call("apply_projectile_hit", damage, status_effects, _get_ammo_context(), global_position)
		_spawn_impact()
	elif body.has_method("apply_hull_damage"):
		body.call("apply_hull_damage", damage)
		_spawn_impact()
		if body.has_method("apply_status_effects"):
			body.call("apply_status_effects", status_effects)
	_release_smoke_trail()
	queue_free()


func _get_ammo_context() -> Dictionary:
	return ammo_context


func _spawn_splash() -> void:
	# Spawn as a sibling of the cannonball, not under current_scene, which
	# can point at a different scene than the one this ball flies in.
	var spawn_parent := get_parent()
	if spawn_parent == null:
		return

	var splash := SplashScene.instantiate() as Node3D
	if splash == null:
		return
	spawn_parent.add_child(splash)
	splash.global_position = Vector3(global_position.x, 0.04, global_position.z)


func _spawn_impact() -> void:
	var spawn_parent := get_parent()
	if spawn_parent == null:
		return

	var impact := ImpactFlashScene.instantiate() as Node3D
	if impact == null:
		return
	spawn_parent.add_child(impact)
	impact.global_position = global_position


# Heavy black powder-smoke trail laid along the flight path (world-space
# particles), so shots read at gameplay camera distance and their arcs can be
# tracked. Built in code: the whole art pipeline is procedural.
func _build_smoke_trail() -> void:
	smoke_trail = GPUParticles3D.new()
	smoke_trail.name = "SmokeTrail"
	smoke_trail.amount = 52
	smoke_trail.lifetime = 0.85
	smoke_trail.local_coords = false
	smoke_trail.emitting = true
	smoke_trail.visibility_aabb = AABB(Vector3(-45.0, -12.0, -45.0), Vector3(90.0, 24.0, 90.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.1
	process_material.initial_velocity_max = 0.45
	process_material.gravity = Vector3(0.0, 0.9, 0.0)
	process_material.scale_min = 0.7
	process_material.scale_max = 1.15
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.5))
	growth.add_point(Vector2(1.0, 1.7))
	var growth_texture := CurveTexture.new()
	growth_texture.curve = growth
	process_material.scale_curve = growth_texture
	# Hold near-black through most of the life so the trail reads heavy, then
	# let go quickly at the end.
	var fade_gradient := Gradient.new()
	fade_gradient.set_color(0, Color(0.06, 0.06, 0.06, 0.9))
	fade_gradient.set_color(1, Color(0.22, 0.22, 0.22, 0.0))
	fade_gradient.add_point(0.4, Color(0.1, 0.1, 0.1, 0.62))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_gradient
	process_material.color_ramp = fade_texture
	smoke_trail.process_material = process_material
	var puff_mesh := QuadMesh.new()
	puff_mesh.size = Vector2(1.0, 1.0)
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.vertex_color_use_as_albedo = true
	puff_material.albedo_texture = EffectSprites.puff_texture()
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_mesh.material = puff_material
	smoke_trail.draw_pass_1 = puff_mesh
	add_child(smoke_trail)


# Hand the trail to our parent before the ball frees so the laid smoke
# lingers and fades instead of vanishing on impact.
func _release_smoke_trail() -> void:
	if smoke_trail == null:
		return
	var trail := smoke_trail
	smoke_trail = null
	trail.emitting = false
	var holder := get_parent()
	if holder == null or not is_inside_tree():
		return
	trail.reparent(holder, true)
	# Self-destruct via a child Timer (not a SceneTreeTimer lambda): if the
	# scene is torn down first, the timer dies with the trail instead of
	# firing against a freed capture.
	var timer := Timer.new()
	timer.wait_time = trail.lifetime + 0.1
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(trail.queue_free)
	trail.add_child(timer)
