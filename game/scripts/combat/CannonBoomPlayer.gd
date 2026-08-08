extends AudioStreamPlayer3D
class_name CannonBoomPlayer

@export var duration: float = 0.35
@export var base_frequency: float = 82.0
@export var volume: float = 0.55

var random := RandomNumberGenerator.new()


func _ready() -> void:
	random.seed = 9
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.5
	stream = generator


func play_boom() -> void:
	if stream == null:
		return

	play()
	var playback := get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	playback.clear_buffer()
	var mix_rate := 22050.0
	var frames := int(duration * mix_rate)
	for index in range(frames):
		var time := float(index) / mix_rate
		var envelope := exp(-7.0 * time)
		var noise := random.randf_range(-1.0, 1.0)
		var low := sin(TAU * base_frequency * time)
		var sample := (noise * 0.62 + low * 0.38) * envelope * volume
		playback.push_frame(Vector2(sample, sample))


func _exit_tree() -> void:
	stop()
	stream = null
