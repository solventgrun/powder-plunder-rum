extends CharacterBody3D
class_name OverworldNpcShip

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")

@export var speed: float = 8.0
@export var turn_speed: float = 3.5
@export_range(1.0, 4.0, 0.1) var overworld_visual_scale: float = 2.0
@export var faction_colors: Dictionary = {
	"spain": Color(0.9, 0.72, 0.18, 0.92),
	"dutch": Color(0.95, 0.36, 0.12, 0.92),
	"england": Color(0.82, 0.12, 0.12, 0.92),
	"france": Color(0.2, 0.36, 0.95, 0.92),
	"pirates": Color(0.05, 0.05, 0.05, 0.92)
}

var encounter_record: Dictionary = {}
var route: Array[Vector3] = []
var route_index: int = 0
var ship_stats: Resource
# Set on a consort — a prize the player kept. She has no route of her own; she
# keeps station on the flagship. Prizes do not fight yet (they follow on the map
# only), which is what Multi-Ship Battle Readiness is for.
var follow_target: Node3D
var follow_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Boats do not climb beaches. CharacterBody3D defaults to grounded motion,
	# which reads the island's flat top as a floor and walks a ship up onto the
	# land instead of stopping her at it.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func configure(record: Dictionary) -> void:
	encounter_record = record.duplicate(true)
	ship_stats = ContentCatalog.build_ship_stats(encounter_record, ContentCatalog.load_ship_types(), ContentCatalog.load_ship_modifications())
	name = str(record.get("id", "OverworldNpcShip"))
	route.clear()
	for waypoint in record.get("route", []):
		route.append(Vector3(float(waypoint.get("x", 0.0)), 0.0, float(waypoint.get("z", 0.0))))
	if route.is_empty():
		route.append(Vector3(float(record.get("start_x", 0.0)), 0.0, float(record.get("start_z", 0.0))))
	global_position = Vector3(float(record.get("start_x", route[0].x)), 0.0, float(record.get("start_z", route[0].z)))
	route_index = 1 if route.size() > 1 else 0
	_apply_ship_stats()
	var ship_visuals := get_node_or_null("VisualRoot/ShipVisualBuilder")
	if ship_visuals:
		ship_visuals.call("apply_visuals", encounter_record, ship_stats)
		ship_visuals.call("update_sail_trim", 0.85)
	_apply_readability(record)


func _physics_process(delta: float) -> void:
	if follow_target:
		_keep_station(delta)
		return
	if route.size() <= 1:
		return
	var target := route[route_index]
	var to_target := target - global_position
	if to_target.length() < 1.2:
		route_index = (route_index + 1) % route.size()
		return

	_steer_towards(to_target, delta)
	velocity = (-global_transform.basis.z).normalized() * speed
	move_and_slide()
	_stay_afloat()


# Station-keeping astern and to one quarter of the flagship. She closes when she
# falls behind and lies quiet once she is in position, so a fleet reads as
# sailing in company rather than as ships piling into each other.
func _keep_station(delta: float) -> void:
	# Orthonormalized, or the flagship's readability scale (a galleon is 3.3x)
	# multiplies the offset with it and the station lands three ship-lengths
	# further out than intended — which reads as a consort ignoring you.
	var station := follow_target.global_position + follow_target.global_transform.basis.orthonormalized() * follow_offset
	var to_station := station - global_position
	var distance := to_station.length()
	if distance < 1.5:
		velocity = velocity.move_toward(Vector3.ZERO, speed * delta)
		move_and_slide()
		_stay_afloat()
		return

	_steer_towards(to_station, delta)
	# A consort needs real reserve to recover station, not a token one: her base
	# overworld pace is below the flagship's, so a small multiplier leaves her
	# trailing further and further astern with no way back. She eases off as she
	# closes so she does not overrun the station.
	var closing_speed := speed * clampf(distance / 10.0, 0.3, 1.9)
	velocity = (-global_transform.basis.z).normalized() * closing_speed
	move_and_slide()
	_stay_afloat()


# Turns the bow towards a point, no faster than the hull will answer her helm.
#
# Both headings must be measured off the SAME vector. The version this replaced
# took the desired heading from the direction to the target but the current one
# from `-basis.z` — the two are half a turn apart, so a ship with her target dead
# ahead computed a 180-degree correction and sailed away from it. Route-following
# NPCs had been doing this since they were written; it only became obvious when a
# consort was supposed to follow something that moves.
func _steer_towards(to_target: Vector3, delta: float) -> void:
	var desired := to_target.normalized()
	var forward := (-global_transform.basis.z).normalized()
	var heading_delta := wrapf(atan2(desired.x, desired.z) - atan2(forward.x, forward.z), -PI, PI)
	rotate_y(clampf(heading_delta, -turn_speed * delta, turn_speed * delta))


# Ships float on one plane. Any overlap — two hulls sharing a spawn, a shove off
# the beach — depenetrates along the cheapest axis, which for a long shallow box
# is vertical; a hull left riding high clears the island collision entirely and
# sails over the land.
func _stay_afloat() -> void:
	if not is_zero_approx(global_position.y):
		global_position.y = 0.0
	velocity.y = 0.0


func _apply_ship_stats() -> void:
	if ship_stats == null:
		return
	speed = maxf(4.5, float(ship_stats.get("max_speed")) * 1.8)
	turn_speed = deg_to_rad(clampf(float(ship_stats.get("turn_rate")), 24.0, 95.0))
	scale = Vector3.ONE * float(ship_stats.get("visual_scale")) * overworld_visual_scale


func _apply_readability(record: Dictionary) -> void:
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.text = str(record.get("name", "NPC Ship"))

	var color: Color = faction_colors.get(str(record.get("faction", "")), Color(0.95, 0.82, 0.26, 0.92))
	var material := StandardMaterial3D.new()
	material.albedo_color = color

	var marker := get_node_or_null("WaterMarker") as MeshInstance3D
	if marker:
		marker.material_override = material
	var flag := get_node_or_null("FactionFlag") as MeshInstance3D
	if flag:
		flag.material_override = material
