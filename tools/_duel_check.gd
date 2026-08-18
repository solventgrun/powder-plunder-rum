extends SceneTree

# Temporary bench for the duel rules engine. The permanent assertions live in
# tools/smoke_test.gd; this exists to eyeball timings and exchange outcomes.

const DuelContextScript := preload("res://game/scripts/duel/DuelContext.gd")
const DuelControllerScript := preload("res://game/scripts/duel/DuelController.gd")
const DuelActionScript := preload("res://game/scripts/duel/DuelAction.gd")

const STEP := 1.0 / 60.0


func _initialize() -> void:
	_check_counters()
	_check_weapon_speed()
	_check_pistol()
	_check_attack_pacing()
	_check_pacing_inputs()
	_check_live_opponent_activity()
	_check_support_melee()
	_run_full_duel()
	quit(0)


# How often does the opponent actually swing? Measured against a player who
# stands still, so the pause knob is isolated from punish behaviour.
func _check_attack_pacing() -> void:
	for level in ["easy", "normal", "hard", "brutal"]:
		var controller: Node = DuelControllerScript.new()
		controller.configure(DuelContextScript.create({
			"rng_seed": 4242,
			"difficulty_id": level,
			"player": {"name": "You", "vigor": 100000.0, "weapon": "longsword"},
			"opponent": DuelContextScript.fighter_from_profile("naval_officer", {"pistol": false})
		}))
		controller.start("longsword")

		var attack_times: Array[float] = []
		var elapsed := 0.0
		var was_winding_up := false
		for index in range(60 * 60):
			controller.advance(STEP)
			elapsed += STEP
			var opponent: Dictionary = controller.get_fighter("opponent")
			var winding_up: bool = str(opponent.get("state")) == controller.STATE_WINDUP
			if winding_up and not was_winding_up:
				attack_times.append(elapsed)
			was_winding_up = winding_up

		var gaps: Array[float] = []
		for index in range(1, attack_times.size()):
			gaps.append(attack_times[index] - attack_times[index - 1])
		var average := 0.0
		for gap in gaps:
			average += gap
		if not gaps.is_empty():
			average /= float(gaps.size())
		print("%s: %d attacks in 60s, average gap %.2fs" % [level, attack_times.size(), average])
		controller.free()


func _make_controller(player_overrides: Dictionary = {}, opponent_overrides: Dictionary = {}) -> Node:
	var controller: Node = DuelControllerScript.new()
	var context := DuelContextScript.create({
		"rng_seed": 12345,
		"player": {"name": "You", "vigor": 100.0, "weapon": "longsword", "pistol": true}.merged(player_overrides, true),
		"opponent": {"name": "Captain", "vigor": 100.0, "weapon": "longsword", "aggression": 0.0, "pistol": false}.merged(opponent_overrides, true)
	})
	controller.configure(context)
	controller.opponent_brain_enabled = false
	return controller


func _settle(controller: Node) -> void:
	# Run out the opening delay so both fighters are ready to act.
	for i in range(200):
		controller.advance(STEP)
		if str(controller.get_fighter("player").get("state")) == controller.STATE_READY:
			return


func _check_counters() -> void:
	for attack in DuelActionScript.ATTACKS:
		var correct := DuelActionScript.counter_for(attack)
		for evasion in DuelActionScript.EVASIONS:
			# A passive opponent: this test is about the attack/evasion table,
			# not about the brain defending itself.
			var controller := _make_controller({}, {"aggression": 0.0, "read_accuracy": 0.0, "reaction_time": 9.0})
			controller.start("longsword")
			_settle(controller)
			controller.submit_opponent_action(attack)
			# Answer like a human would: a beat after the tell appears.
			for i in range(12):
				controller.advance(STEP)
			controller.submit_player_action(evasion)
			for i in range(90):
				controller.advance(STEP)
			var vigor: float = controller.get_vigor_fraction("player")
			var expected := "BLOCKED" if evasion == correct else "HIT"
			var actual := "BLOCKED" if is_equal_approx(vigor, 1.0) else "HIT"
			print("%s vs %s -> %s (expected %s, vigor %.2f)" % [attack, evasion, actual, expected, vigor])
			controller.free()


func _check_weapon_speed() -> void:
	for weapon in ["cutlass", "longsword", "broadsword"]:
		var controller := _make_controller({}, {"aggression": 0.0, "read_accuracy": 0.0, "reaction_time": 9.0})
		controller.start(weapon)
		_settle(controller)
		controller.submit_player_action(DuelActionScript.CHOP)
		var windup: float = float(controller.get_fighter("player").get("state_duration"))
		var frames := 0
		while str(controller.get_fighter("opponent").get("state")) != controller.STATE_STAGGER and frames < 300:
			controller.advance(STEP)
			frames += 1
		print("%s windup %.2fs, damage dealt %.1f" % [weapon, windup, (1.0 - controller.get_vigor_fraction("opponent")) * 100.0])
		controller.free()


func _check_pistol() -> void:
	# Unmolested draw: the shot should land and be spent.
	var controller := _make_controller({}, {"aggression": 0.0, "read_accuracy": 0.0, "reaction_time": 9.0})
	controller.start("longsword")
	_settle(controller)
	controller.submit_player_action(DuelActionScript.PISTOL)
	for i in range(120):
		controller.advance(STEP)
	print("clean shot: opponent vigor %.2f, pistol available %s" % [controller.get_vigor_fraction("opponent"), controller.can_use_pistol("player")])
	controller.submit_player_action(DuelActionScript.PISTOL)
	print("second attempt accepted: %s" % (str(controller.get_fighter("player").get("state")) == controller.STATE_PISTOL))
	controller.free()

	# Interrupted draw: a hit taken mid-draw should spoil the shot outright.
	var punished := _make_controller({}, {"aggression": 0.0, "read_accuracy": 0.0, "reaction_time": 9.0})
	punished.start("longsword")
	_settle(punished)
	punished.submit_player_action(DuelActionScript.PISTOL)
	punished.advance(STEP)
	punished.submit_opponent_action(DuelActionScript.THRUST)
	for i in range(120):
		punished.advance(STEP)
	print("spoiled shot: opponent vigor %.2f, player vigor %.2f, pistol available %s" % [punished.get_vigor_fraction("opponent"), punished.get_vigor_fraction("player"), punished.can_use_pistol("player")])
	punished.free()


func _run_full_duel() -> void:
	var controller := _make_controller({}, {"aggression": 0.7, "read_accuracy": 0.5, "pistol": true})
	controller.opponent_brain_enabled = true
	var finished := {"result": {}}
	controller.duel_finished.connect(func(result): finished["result"] = result)
	controller.start("cutlass")
	var frames := 0
	while finished["result"].is_empty() and frames < 60 * 120:
		controller.advance(STEP)
		# Crude auto-fencer: always answer the tell correctly, otherwise press.
		var opponent: Dictionary = controller.get_fighter("opponent")
		var player: Dictionary = controller.get_fighter("player")
		if str(player.get("state")) == controller.STATE_READY:
			if str(opponent.get("state")) == controller.STATE_WINDUP:
				controller.submit_player_action(DuelActionScript.counter_for(str(opponent.get("action"))))
			elif str(opponent.get("state")) in [controller.STATE_RECOVER, controller.STATE_STAGGER]:
				controller.submit_player_action(DuelActionScript.THRUST)
		frames += 1
	print("full duel: %s" % finished["result"])
	controller.free()


# Diagnostic: what the brain actually thinks it is doing on normal.
func _check_pacing_inputs() -> void:
	var controller: Node = DuelControllerScript.new()
	controller.configure(DuelContextScript.create({
		"rng_seed": 4242,
		"difficulty_id": "normal",
		"player": {"name": "You", "vigor": 100000.0, "weapon": "longsword"},
		"opponent": DuelContextScript.fighter_from_profile("naval_officer", {"pistol": false})
	}))
	controller.start("longsword")
	var opponent: Dictionary = controller.get_fighter("opponent")
	var data: Dictionary = opponent.get("data", {})
	print("duel difficulty section: %s" % controller.difficulty)
	print("opponent aggression %.3f reaction %.3f read %.3f" % [float(data.get("aggression")), float(data.get("reaction_time")), float(data.get("read_accuracy"))])
	var actions := {}
	var was_state := ""
	for index in range(60 * 30):
		controller.advance(STEP)
		var state := str(controller.get_fighter("opponent").get("state"))
		if state != was_state:
			actions[state] = int(actions.get(state, 0)) + 1
			was_state = state
	print("opponent state entries over 30s: %s" % actions)
	controller.free()


# Reproduce a real boarding: a softened enemy (the usual reason you board) at
# normal difficulty, against a player who fences at a human sort of rate.
func _check_live_opponent_activity() -> void:
	for weapon in ["cutlass", "longsword"]:
		for weariness in [0.0, 0.75]:
			var opponent := DuelContextScript.fighter_from_profile("naval_officer", {"pistol": false})
			# Mirror BoardingController's condition scaling.
			opponent["reaction_time"] = float(opponent.get("reaction_time")) + 0.22 * weariness
			opponent["read_accuracy"] = maxf(float(opponent.get("read_accuracy")) - 0.3 * weariness, 0.22)
			opponent["aggression"] = maxf(float(opponent.get("aggression")) - 0.35 * weariness, 0.32)
			var controller: Node = DuelControllerScript.new()
			controller.configure(DuelContextScript.create({
				"rng_seed": 777,
				"difficulty_id": "normal",
				"player": {"name": "You", "vigor": 100000.0, "weapon": weapon},
				"opponent": opponent
			}))
			controller.start(weapon)

			var counts := {"opponent_attacks": 0, "opponent_evades": 0, "player_attacks": 0, "player_hits": 0}
			controller.hit_landed.connect(func(side, _a, _d, _k):
				if side == "player":
					counts["player_hits"] += 1)
			var was_opponent := ""
			var was_player := ""
			for index in range(60 * 60):
				controller.advance(STEP)
				var opponent_state := str(controller.get_fighter("opponent").get("state"))
				var player_state := str(controller.get_fighter("player").get("state"))
				if opponent_state != was_opponent:
					if opponent_state == controller.STATE_WINDUP:
						counts["opponent_attacks"] += 1
					elif opponent_state == controller.STATE_EVADE:
						counts["opponent_evades"] += 1
					was_opponent = opponent_state
				if player_state != was_player:
					was_player = player_state
				# Player fences steadily: attack whenever able.
				if player_state == controller.STATE_READY:
					if controller.submit_player_action(DuelActionScript.THRUST):
						counts["player_attacks"] += 1
			var data: Dictionary = controller.get_fighter("opponent").get("data", {})
			print("%s vs weariness %.2f -> reaction %.2f read %.2f aggression %.2f | opponent attacks %d, evades %d | player attacks %d, hits %d" % [
				weapon, weariness, float(data.get("reaction_time")), float(data.get("read_accuracy")), float(data.get("aggression")),
				counts["opponent_attacks"], counts["opponent_evades"], counts["player_attacks"], counts["player_hits"]])
			controller.free()


# Crew melee: how fast does a boarding bleed, and can a numbers gap actually
# decide a fight before the captains do?
func _check_support_melee() -> void:
	for matchup in [[45.0, 45.0], [45.0, 15.0], [45.0, 28.0], [50.0, 50.0], [100.0, 50.0], [40.0, 90.0]]:
		var controller: Node = DuelControllerScript.new()
		controller.configure(DuelContextScript.create({
			"rng_seed": 31337,
			"difficulty_id": "normal",
			"player": {"name": "You", "vigor": 100000.0, "weapon": "longsword"},
			"opponent": {"name": "Captain", "vigor": 100000.0, "weapon": "longsword", "aggression": 0.4},
			"support": {
				"player": {"label": "Pirates", "count": matchup[0], "strength": 1.0},
				"opponent": {"label": "Spain", "count": matchup[1], "strength": 1.0}
			}
		}))
		controller.start("longsword")
		var broken := {"side": "", "at": 0.0}
		controller.support_broken.connect(func(side): broken["side"] = side)
		var elapsed := 0.0
		var snapshots := {}
		for index in range(60 * 60):
			controller.advance(STEP)
			elapsed += STEP
			if broken["side"] != "" and broken["at"] == 0.0:
				broken["at"] = elapsed
			for mark in [10, 25, 40]:
				if absf(elapsed - float(mark)) < STEP * 0.5:
					snapshots[mark] = "%.0f v %.0f" % [controller.get_support_count("player"), controller.get_support_count("opponent")]
		print("%.0f v %.0f -> 10s %s | 25s %s | 40s %s | broken: %s at %.0fs" % [
			matchup[0], matchup[1],
			str(snapshots.get(10, "-")), str(snapshots.get(25, "-")), str(snapshots.get(40, "-")),
			str(broken["side"]) if broken["side"] != "" else "none", float(broken["at"])])
		controller.free()
