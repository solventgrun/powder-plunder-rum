extends Node

const FleetScript := preload("res://game/scripts/session/Fleet.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		failures.append("GameSession autoload is missing.")
	else:
		_seed_session(session)
		await _check_scene("res://game/scenes/PortMenu.tscn")
		await _check_scene("res://game/scenes/Overworld.tscn")
		await _check_sell(session)
		await _check_buy_provisions(session)
		await _check_repair(session)
		await _check_hire(session)
		await _check_fleet(session)

	for failure in failures:
		push_error(failure)
	print("PortProbe %s" % ("passed" if failures.is_empty() else "failed"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _seed_session(session: Node) -> void:
	var fleet := FleetScript.starting_fleet()
	var flagship: Dictionary = fleet[0]
	FleetScript.set_manifest(flagship, {"sugar": 2, "gold": 1})
	flagship["condition"]["hull_fraction"] = 0.8
	flagship["condition"]["sail_fraction"] = 0.9
	session.set("fleet", fleet)
	session.set("flagship_index", 0)
	session.set("gold", 25)

	var prize_loadout: Dictionary = flagship.get("loadout", {}).duplicate(true)
	prize_loadout["ship_type"] = "sloop"
	prize_loadout["crew"] = 8
	var prize := FleetScript.make_ship(prize_loadout, "Probe Prize", "probe_prize", {})
	session.call("add_prize", prize)


func _check_scene(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append("Could not load %s." % path)
		return null
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	if scene.get_script() == null:
		failures.append("%s instantiated without its screen script." % path)
	scene.queue_free()
	await get_tree().process_frame
	return scene


func _check_sell(session: Node) -> void:
	var scene := await _show("res://game/scenes/PortSellCargo.tscn")
	if scene == null:
		return
	if scene.get("sale_sliders").is_empty():
		failures.append("Sell cargo should expose sale sliders.")
	else:
		var key: String = str(scene.get("sale_sliders").keys()[0])
		scene.get("sale_sliders")[key].value = 1
		var before := int(session.get("gold"))
		scene.call("_on_sell")
		if int(session.get("gold")) <= before:
			failures.append("Selling cargo should add gold to the purse.")
	scene.queue_free()
	await get_tree().process_frame


func _check_repair(session: Node) -> void:
	var scene := await _show("res://game/scenes/PortRepair.tscn")
	if scene == null:
		return
	if scene.get("repair_sliders").is_empty():
		failures.append("Repair screen should expose repair sliders.")
	else:
		for key: String in scene.get("repair_sliders"):
			if str(key).ends_with(":hull"):
				scene.get("repair_sliders")[key].value = 1
				break
		var before := float((session.get("fleet") as Array)[0]["condition"]["hull_fraction"])
		scene.call("_on_repair")
		var after := float((session.get("fleet") as Array)[0]["condition"]["hull_fraction"])
		if after <= before:
			failures.append("Repairing should improve ship condition.")
	scene.queue_free()
	await get_tree().process_frame


func _check_buy_provisions(session: Node) -> void:
	var scene := await _show("res://game/scenes/PortBuyProvisions.tscn")
	if scene == null:
		return
	if scene.get("buy_sliders").is_empty():
		failures.append("Buy provisions should expose purchase sliders.")
	else:
		scene.get("buy_sliders")["0"].value = 1
		var ship: Dictionary = (session.get("fleet") as Array)[0]
		var before := int(FleetScript.get_manifest(ship).get("provisions", 0))
		scene.call("_on_buy")
		var after := int(FleetScript.get_manifest(ship).get("provisions", 0))
		if after <= before:
			failures.append("Buying provisions should add provisions cargo.")
	scene.queue_free()
	await get_tree().process_frame


func _check_hire(session: Node) -> void:
	var scene := await _show("res://game/scenes/PortHireCrew.tscn")
	if scene == null:
		return
	if scene.get("hire_sliders").is_empty():
		failures.append("Hire screen should expose hire sliders.")
	else:
		scene.get("hire_sliders")["0"].value = 1
		var before := FleetScript.get_crew((session.get("fleet") as Array)[0])
		scene.call("_on_hire")
		var after := FleetScript.get_crew((session.get("fleet") as Array)[0])
		if after <= before:
			failures.append("Hiring should add crew.")
	scene.queue_free()
	await get_tree().process_frame


func _check_fleet(session: Node) -> void:
	var scene := await _show("res://game/scenes/FleetManagement.tscn")
	if scene == null:
		return
	scene.call("_on_set_flagship", 1)
	if int(session.get("flagship_index")) != 1:
		failures.append("Fleet management should switch the flagship.")
	if scene.get("ration_sliders").is_empty():
		failures.append("Fleet management should expose rum-ration sliders.")
	else:
		scene.get("ration_sliders")["0"].value = 3
		var ship: Dictionary = (session.get("fleet") as Array)[0]
		if int(ship.get("condition", {}).get("rum_ration", -1)) != 3:
			failures.append("Changing a rum ration should update the ship condition.")
	scene.queue_free()
	await get_tree().process_frame


func _show(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append("Could not load %s." % path)
		return null
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	if scene.get_script() == null:
		failures.append("%s instantiated without its screen script." % path)
		scene.queue_free()
		await get_tree().process_frame
		return null
	return scene
