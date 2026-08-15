extends Node

# Autoload that owns ocean wave time. Advances the shared ocean material's
# wave_time uniform and lets ships sample matching wave heights on the CPU.
# sample_wave_value() must mirror vertex() in StylizedOcean.gdshader.

const OCEAN_MATERIAL := preload("res://game/materials/StylizedOceanMaterial.tres")

var wave_time: float = 0.0
var wave_height: float = 0.5
var wave_scale: float = 0.28
var wave_speed: float = 0.8


func _ready() -> void:
	wave_height = float(OCEAN_MATERIAL.get_shader_parameter("wave_height"))
	wave_scale = float(OCEAN_MATERIAL.get_shader_parameter("wave_scale"))
	wave_speed = float(OCEAN_MATERIAL.get_shader_parameter("wave_speed"))


func _process(delta: float) -> void:
	wave_time += delta
	OCEAN_MATERIAL.set_shader_parameter("wave_time", wave_time)


func sample_wave_value(world_x: float, world_z: float) -> float:
	var wave_a := sin((world_x * wave_scale) + (wave_time * wave_speed))
	var wave_b := cos((world_z * wave_scale * 1.37) + (wave_time * wave_speed * 0.72))
	var wave_c := sin(((world_x + world_z) * wave_scale * 0.68) - (wave_time * wave_speed * 0.45))
	return (wave_a + wave_b + wave_c) / 3.0


func sample_height(world_position: Vector3) -> float:
	return sample_wave_value(world_position.x, world_position.z) * wave_height
