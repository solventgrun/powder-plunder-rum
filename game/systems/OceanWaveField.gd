extends Node

# Autoload that owns ocean wave time. Advances the shared ocean material's
# wave_time uniform and lets ships sample matching wave heights on the CPU.
# The chop + Gerstner swell math below must mirror vertex() in
# StylizedOcean.gdshader exactly — any displacement change happens in BOTH.

const OCEAN_MATERIAL := preload("res://game/materials/StylizedOceanMaterial.tres")

# Fixed relation of the derived second swell to the primary (shader SWELL2_*).
const SWELL2_ROTATE_COS := 0.83
const SWELL2_ROTATE_SIN := 0.56
const SWELL2_WAVELENGTH := 0.6
const SWELL2_AMPLITUDE := 0.55
const SWELL2_SPEED := 0.8
const SWELL2_PHASE := 2.1

var wave_time: float = 0.0
var wave_height: float = 0.5
var wave_scale: float = 0.28
var wave_speed: float = 0.8

# Per-component swell tables built in _ready: [direction, k, amplitude,
# horizontal sway qa, phase speed, phase offset].
var swell_components: Array = []


func _ready() -> void:
	wave_height = float(OCEAN_MATERIAL.get_shader_parameter("wave_height"))
	wave_scale = float(OCEAN_MATERIAL.get_shader_parameter("wave_scale"))
	wave_speed = float(OCEAN_MATERIAL.get_shader_parameter("wave_speed"))
	var direction: Vector2 = OCEAN_MATERIAL.get_shader_parameter("swell_direction")
	var wavelength := float(OCEAN_MATERIAL.get_shader_parameter("swell_wavelength"))
	var amplitude := float(OCEAN_MATERIAL.get_shader_parameter("swell_amplitude"))
	var steepness := float(OCEAN_MATERIAL.get_shader_parameter("swell_steepness"))
	var speed := float(OCEAN_MATERIAL.get_shader_parameter("swell_speed"))
	var d1 := direction.normalized()
	var d2 := Vector2(
		SWELL2_ROTATE_COS * d1.x - SWELL2_ROTATE_SIN * d1.y,
		SWELL2_ROTATE_SIN * d1.x + SWELL2_ROTATE_COS * d1.y)
	var k1 := TAU / wavelength
	var k2 := TAU / (wavelength * SWELL2_WAVELENGTH)
	swell_components = [
		[d1, k1, amplitude, steepness * 0.6 / k1, speed, 0.0],
		[d2, k2, amplitude * SWELL2_AMPLITUDE, steepness * 0.4 / k2, speed * SWELL2_SPEED, SWELL2_PHASE]
	]


func _process(delta: float) -> void:
	wave_time += delta
	OCEAN_MATERIAL.set_shader_parameter("wave_time", wave_time)


func sample_wave_value(world_x: float, world_z: float) -> float:
	var wave_a := sin((world_x * wave_scale) + (wave_time * wave_speed))
	var wave_b := cos((world_z * wave_scale * 1.37) + (wave_time * wave_speed * 0.72))
	var wave_c := sin(((world_x + world_z) * wave_scale * 0.68) - (wave_time * wave_speed * 0.45))
	return (wave_a + wave_b + wave_c) / 3.0


func _swell_horizontal(at: Vector2) -> Vector2:
	var offset := Vector2.ZERO
	for component in swell_components:
		var phase: float = component[1] * (component[0].dot(at) - component[4] * wave_time) + component[5]
		offset += component[0] * (component[3] * cos(phase))
	return offset


func _swell_height(at: Vector2) -> float:
	var height := 0.0
	for component in swell_components:
		var phase: float = component[1] * (component[0].dot(at) - component[4] * wave_time) + component[5]
		height += component[2] * sin(phase)
	return height


func sample_height(world_position: Vector3) -> float:
	# Gerstner swell moves surface points sideways; invert that horizontal
	# displacement (fixed-point, converges because total pinch < 1) so the
	# returned height matches what is actually rendered above this position.
	var target := Vector2(world_position.x, world_position.z)
	var source := target
	for iteration in range(3):
		source = target - _swell_horizontal(source)
	return sample_wave_value(source.x, source.y) * wave_height + _swell_height(source)
