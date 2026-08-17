extends Node3D
class_name ShipWaveMotion

# Bobs, pitches, and rolls a ship's VisualRoot to ride the sampled ocean
# waves, and heels the hull from turn rate and wind pressure. Lives on a
# visual-only child so gameplay transforms on the ship body (movement,
# sinking, collision) stay untouched.
# Amounts above 1.0 deliberately exaggerate the honest wave response —
# at gameplay camera distances the physical amplitudes read as static.

@export var bow_point: Vector3 = Vector3(0.0, 0.0, -1.7)
@export var stern_point: Vector3 = Vector3(0.0, 0.0, 1.7)
@export var beam_half_width: float = 0.75
@export_range(0.0, 3.0, 0.05) var bob_amount: float = 1.5
@export_range(0.0, 3.0, 0.05) var pitch_amount: float = 1.8
@export_range(0.0, 3.0, 0.05) var roll_amount: float = 1.8
# Heel composes with the wave-driven roll above: both are summed into
# rotation.z here so the two roll sources stay in one place.
@export_range(0.0, 15.0, 0.5, "degrees") var turn_heel_degrees: float = 6.0
@export_range(0.0, 15.0, 0.5, "degrees") var wind_heel_degrees: float = 7.0
@export_range(10.0, 180.0, 1.0, "degrees_per_second") var full_heel_turn_rate: float = 70.0
@export_range(0.5, 12.0, 0.1) var heel_response: float = 3.0
# Broadside recoil kick, decaying back to zero between volleys.
@export_range(0.0, 8.0, 0.1, "degrees") var recoil_roll_degrees: float = 2.2
@export_range(1.0, 12.0, 0.1) var recoil_decay: float = 5.0
# Damage listing: the fourth roll source — a slow wounded lean (port rail
# down, slightly by the head) driven by ShipVisualBuilder as hull fraction
# drops. Replaces the old translucent damage-overlay box.
@export_range(0.0, 15.0, 0.5, "degrees") var max_list_roll_degrees: float = 9.5
@export_range(0.0, 8.0, 0.25, "degrees") var max_list_pitch_degrees: float = 3.2
@export_range(0.1, 5.0, 0.1) var list_response: float = 0.8

var wave_field: Node
var ship: Node3D
var previous_yaw: float = 0.0
var yaw_rate_degrees: float = 0.0
var heel_radians: float = 0.0
var recoil_roll: float = 0.0
var list_severity: float = 0.0
var list_roll: float = 0.0
var list_pitch: float = 0.0


# Broadside kick: the deck rolls away from the firing side, then eases back.
# side: -1 = port guns, +1 = starboard guns (positive Z dips the port rail).
func add_recoil_roll(side: int) -> void:
	var kick := deg_to_rad(recoil_roll_degrees)
	recoil_roll = clampf(recoil_roll + kick * float(side), -kick * 2.0, kick * 2.0)


# severity 0 = sound hull, 1 = full wounded lean at zero hull.
func set_damage_list(severity: float) -> void:
	list_severity = clampf(severity, 0.0, 1.0)


func _ready() -> void:
	# Defensive: tolerate hosts without the autoload (editor tool contexts).
	# Note --script test runs DO instance autoloads, so this is live there.
	wave_field = get_node_or_null("/root/OceanWaveField")
	ship = get_parent() as Node3D
	if ship:
		previous_yaw = ship.rotation.y


func _physics_process(delta: float) -> void:
	# Yaw rate is sampled here because the ship body only turns in physics
	# ticks; sampling per render frame would stair-step between ticks.
	if ship == null or delta <= 0.0:
		return
	yaw_rate_degrees = rad_to_deg(wrapf(ship.rotation.y - previous_yaw, -PI, PI)) / delta
	previous_yaw = ship.rotation.y


func _process(delta: float) -> void:
	if wave_field == null or ship == null:
		return
	var bow_world: Vector3 = ship.to_global(bow_point)
	var stern_world: Vector3 = ship.to_global(stern_point)
	var port_world: Vector3 = ship.to_global(Vector3(-beam_half_width, 0.0, 0.0))
	var starboard_world: Vector3 = ship.to_global(Vector3(beam_half_width, 0.0, 0.0))
	var bow_height: float = wave_field.sample_height(bow_world)
	var stern_height: float = wave_field.sample_height(stern_world)
	var port_height: float = wave_field.sample_height(port_world)
	var starboard_height: float = wave_field.sample_height(starboard_world)
	# Ships are scaled up for readability; divide so the bob stays a
	# world-space offset instead of growing with the ship.
	var world_scale: float = maxf(ship.global_transform.basis.get_scale().y, 0.001)
	position.y = (bow_height + stern_height) * 0.5 * bob_amount / world_scale
	# The list eases in slowly — a ship settling as it takes on water, not a
	# snap on the damaging hit.
	var list_blend := 1.0 - exp(-list_response * delta)
	list_roll = lerpf(list_roll, deg_to_rad(max_list_roll_degrees) * list_severity, list_blend)
	list_pitch = lerpf(list_pitch, -deg_to_rad(max_list_pitch_degrees) * list_severity, list_blend)
	var pitch_span := Vector2(bow_world.x - stern_world.x, bow_world.z - stern_world.z).length()
	if pitch_span > 0.01:
		rotation.x = atan2(bow_height - stern_height, pitch_span) * pitch_amount + list_pitch
	_update_heel(delta)
	recoil_roll *= exp(-recoil_decay * delta)
	var wave_roll := 0.0
	var roll_span := Vector2(starboard_world.x - port_world.x, starboard_world.z - port_world.z).length()
	if roll_span > 0.01:
		wave_roll = atan2(starboard_height - port_height, roll_span) * roll_amount
	rotation.z = wave_roll + heel_radians + recoil_roll + list_roll


func _update_heel(delta: float) -> void:
	var target := 0.0
	var sunk: Variant = ship.get("is_sunk")
	if sunk == null or not bool(sunk):
		# Turning starboard (negative yaw rate) heels the deck outward to
		# port — positive Z roll dips the port rail.
		target = deg_to_rad(turn_heel_degrees) * clampf(-yaw_rate_degrees / full_heel_turn_rate, -1.0, 1.0)
		target += _wind_heel_target()
	heel_radians = lerpf(heel_radians, target, 1.0 - exp(-heel_response * delta))


func _wind_heel_target() -> float:
	# Overworld NPC ships carry no wind system or trim; they get turn heel only.
	var wind_system := ship.get("wind_system") as Node
	if wind_system == null:
		return 0.0
	var wind_direction: Vector3 = wind_system.get_wind_direction()
	var wind_speed_factor := 1.0
	if wind_system.has_method("get_wind_speed_factor"):
		wind_speed_factor = float(wind_system.call("get_wind_speed_factor"))
	var sail_trim := 1.0
	var trim_value: Variant = ship.get("sail_trim")
	if trim_value != null:
		sail_trim = clampf(float(trim_value), 0.0, 1.0)
	# Wind blowing toward starboard (positive lateral) presses the ship over
	# so the leeward starboard rail dips — negative Z roll.
	var lateral_wind: float = wind_direction.dot(ship.global_transform.basis.x.normalized())
	return deg_to_rad(wind_heel_degrees) * -lateral_wind * sail_trim * clampf(wind_speed_factor, 0.0, 1.2)
