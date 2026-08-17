extends SceneTree

# Scratch check for the Gerstner CPU mirror: how far the fixed-point
# inversion in OceanWaveField.sample_height is from a true inverse. Residual
# is |q + D(q) - p| — the horizontal error of the recovered source point.
# Run: godot --headless --path . --script res://tools/_swell_check.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var field := root.get_node_or_null("/root/OceanWaveField")
	if field == null:
		push_error("OceanWaveField autoload missing")
		quit(1)
		return
	var worst := 0.0
	var total := 0.0
	var count := 0
	for time_sample in [0.0, 7.3, 41.9, 133.7]:
		field.wave_time = time_sample
		for x in range(-120, 121, 8):
			for z in range(-120, 121, 8):
				var target := Vector2(float(x), float(z))
				var source := target
				for iteration in range(3):
					source = target - field._swell_horizontal(source)
				var residual: float = (source + field._swell_horizontal(source) - target).length()
				worst = maxf(worst, residual)
				total += residual
				count += 1
	print("swell inversion residual: worst %.4f, mean %.4f over %d samples" % [worst, total / count, count])
	quit(0)
