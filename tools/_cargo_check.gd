extends SceneTree

# Disposable bench for the cargo data layer: proves the hand-rolled YAML parser
# reads `cargo:` manifests and `cargo_role:` fallbacks, and prints what each
# ship ends up carrying so the tuning is visible.

const ContentCatalog := preload("res://game/scripts/content/ContentCatalog.gd")
const ContentValidator := preload("res://game/scripts/content/ContentValidator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cargo_types := ContentCatalog.load_cargo_types()
	print("Cargo types loaded: %d" % cargo_types.size())
	for id in cargo_types:
		var record: Dictionary = cargo_types[id]
		var weight := float(record.get("weight", 0.0))
		var value := float(record.get("value", 0.0))
		var effect := str(record.get("effect", {}).get("kind", "-"))
		print("  %-14s %-8s wt %-3s val %-3s  %5.1f/ton  effect %s" % [id, str(record.get("role", "?")), weight, value, value / maxf(weight, 0.01), effect])

	var roles := ContentCatalog.load_cargo_roles()
	print("Cargo roles loaded: %d (%s)" % [roles.size(), ", ".join(roles.keys())])

	print("--- overworld holds ---")
	for record in ContentCatalog.load_overworld_ship_records():
		var manifest: Dictionary = record.get("cargo", {})
		var weight := ContentCatalog.calculate_cargo_weight(manifest, cargo_types)
		var value := ContentCatalog.calculate_cargo_value(manifest, cargo_types)
		print("%s (%s): free hold %.0f, carrying %.0f tons worth %.0f" % [record.get("name"), record.get("ship_type"), ContentCatalog.get_free_hold(record), weight, value])
		print("    %s" % str(manifest))

	var player := ContentCatalog.load_player_ship_record()
	print("--- player ---")
	print("free hold %.0f, manifest %s" % [ContentCatalog.get_free_hold(player), str(player.get("cargo", {}))])

	var result: Dictionary = ContentValidator.validate_all()
	for warning in result.get("warnings", []):
		print("WARN  %s" % warning)
	for error in result.get("errors", []):
		print("ERROR %s" % error)
	print("Validation: %d errors, %d warnings" % [result.get("errors", []).size(), result.get("warnings", []).size()])
	quit(0)
