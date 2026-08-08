extends SceneTree

const ContentValidator := preload("res://game/scripts/content/ContentValidator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := ContentValidator.validate_all()
	var errors: Array[String] = result.errors
	var warnings: Array[String] = result.warnings

	for warning in warnings:
		push_warning(warning)

	if errors.is_empty():
		print("Content validation passed with %d warning(s)." % warnings.size())
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)
