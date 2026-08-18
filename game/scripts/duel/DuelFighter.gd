class_name DuelFighter
extends Node3D

# A chunky procedural fencer: boxes for limbs, a coat in the fighter's colours,
# a hat, and a sword. Deliberately primitive — the first pass exists to make the
# duel legible and playable, and better geometry later is a swap-in behind this
# script's `apply_state` / `play_strike` interface.
#
# The figure is built facing +X. The opposing fighter is simply rotated 180
# degrees about Y, so every pose below is authored once.

const SKIN := Color(0.85, 0.69, 0.53)
const BOOT := Color(0.16, 0.11, 0.07)
const BLADE := Color(0.86, 0.88, 0.92)
const HILT := Color(0.72, 0.58, 0.24)
const IRON := Color(0.22, 0.22, 0.25)

# Every pose is the same set of joints, so blending between any two is a plain
# lerp per channel. Angles are degrees; offsets are metres.
const POSES := {
	"guard": {"sword_arm": 38.0, "forearm": -38.0, "off_arm": -28.0, "torso": -7.0, "head": 0.0, "body_x": 0.0, "body_y": 0.0, "stance": 16.0},
	"windup_high": {"sword_arm": 138.0, "forearm": -18.0, "off_arm": -40.0, "torso": -16.0, "head": -6.0, "body_x": -0.12, "body_y": 0.02, "stance": 18.0},
	"windup_mid": {"sword_arm": 12.0, "forearm": -122.0, "off_arm": -34.0, "torso": -12.0, "head": -3.0, "body_x": -0.14, "body_y": 0.0, "stance": 20.0},
	"windup_low": {"sword_arm": -58.0, "forearm": -28.0, "off_arm": -30.0, "torso": -5.0, "head": -2.0, "body_x": -0.12, "body_y": -0.04, "stance": 22.0},
	"strike_high": {"sword_arm": -28.0, "forearm": 4.0, "off_arm": -55.0, "torso": 14.0, "head": 8.0, "body_x": 0.30, "body_y": -0.05, "stance": 30.0},
	"strike_mid": {"sword_arm": 6.0, "forearm": 2.0, "off_arm": -70.0, "torso": 9.0, "head": 4.0, "body_x": 0.40, "body_y": -0.08, "stance": 36.0},
	"strike_low": {"sword_arm": -52.0, "forearm": 6.0, "off_arm": -60.0, "torso": 7.0, "head": 3.0, "body_x": 0.32, "body_y": -0.12, "stance": 34.0},
	"recover": {"sword_arm": 14.0, "forearm": -16.0, "off_arm": -20.0, "torso": 2.0, "head": 2.0, "body_x": 0.10, "body_y": -0.02, "stance": 22.0},
	"jump": {"sword_arm": 52.0, "forearm": -46.0, "off_arm": -70.0, "torso": -4.0, "head": 0.0, "body_x": -0.04, "body_y": 0.62, "stance": 44.0},
	"duck": {"sword_arm": 46.0, "forearm": -50.0, "off_arm": -12.0, "torso": -26.0, "head": -10.0, "body_x": -0.02, "body_y": -0.48, "stance": 46.0},
	"parry": {"sword_arm": 78.0, "forearm": -84.0, "off_arm": -34.0, "torso": -5.0, "head": 0.0, "body_x": -0.05, "body_y": 0.0, "stance": 18.0},
	"stagger": {"sword_arm": 58.0, "forearm": -20.0, "off_arm": -78.0, "torso": -27.0, "head": -14.0, "body_x": -0.32, "body_y": -0.03, "stance": 26.0},
	"taunt": {"sword_arm": -34.0, "forearm": -14.0, "off_arm": 122.0, "torso": 8.0, "head": 6.0, "body_x": 0.06, "body_y": 0.0, "stance": 14.0},
	"pistol": {"sword_arm": -26.0, "forearm": -12.0, "off_arm": 4.0, "torso": -4.0, "head": 0.0, "body_x": -0.02, "body_y": 0.0, "stance": 18.0},
	"yield": {"sword_arm": -74.0, "forearm": -8.0, "off_arm": -6.0, "torso": -52.0, "head": -26.0, "body_x": -0.18, "body_y": -0.44, "stance": 74.0},
	"waiting": {"sword_arm": 30.0, "forearm": -30.0, "off_arm": -22.0, "torso": -4.0, "head": 0.0, "body_x": -0.06, "body_y": 0.0, "stance": 12.0}
}

const STRIKE_HOLD := 0.16

var coat_color := Color(0.23, 0.14, 0.09)
var accent_color := Color(0.56, 0.10, 0.06)
var hat_style := "tricorn"

var _pose: Dictionary = {}
var _target_pose: Dictionary = {}
var _blend_speed: float = 9.0
var _strike_hold: float = 0.0
var _idle_phase: float = 0.0

var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _sword_shoulder: Node3D
var _sword_elbow: Node3D
var _off_shoulder: Node3D
var _leg_front: Node3D
var _leg_back: Node3D
var _pistol_mesh: MeshInstance3D
var _sword: Node3D


func build(fighter_data: Dictionary) -> void:
	coat_color = _parse_color(str(fighter_data.get("coat", "3a2416")), coat_color)
	accent_color = _parse_color(str(fighter_data.get("accent", "8f1a10")), accent_color)
	hat_style = str(fighter_data.get("hat", "tricorn"))
	_idle_phase = randf() * TAU

	for child in get_children():
		child.queue_free()

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	_leg_front = _joint(_body, "LegFront", Vector3(0.0, 0.78, -0.13))
	_box(_leg_front, Vector3(0.19, 0.8, 0.22), Vector3(0.0, -0.4, 0.0), BOOT)
	_leg_back = _joint(_body, "LegBack", Vector3(0.0, 0.78, 0.13))
	_box(_leg_back, Vector3(0.19, 0.8, 0.22), Vector3(0.0, -0.4, 0.0), BOOT)

	_torso = _joint(_body, "Torso", Vector3(0.0, 0.78, 0.0))
	_box(_torso, Vector3(0.34, 0.62, 0.5), Vector3(0.0, 0.31, 0.0), coat_color)
	# Lapels and sash: the accent colour is what reads at a glance, so give it
	# real surface area rather than piping.
	_box(_torso, Vector3(0.06, 0.58, 0.22), Vector3(0.16, 0.32, 0.0), accent_color)
	_box(_torso, Vector3(0.37, 0.1, 0.53), Vector3(0.0, 0.12, 0.0), accent_color)

	_head = _joint(_torso, "Head", Vector3(0.0, 0.64, 0.0))
	_box(_head, Vector3(0.26, 0.28, 0.28), Vector3(0.02, 0.14, 0.0), SKIN)
	_build_hat(_head)

	_sword_shoulder = _joint(_torso, "SwordArm", Vector3(0.04, 0.5, -0.28))
	_box(_sword_shoulder, Vector3(0.36, 0.15, 0.16), Vector3(0.18, 0.0, 0.0), coat_color)
	_sword_elbow = _joint(_sword_shoulder, "Forearm", Vector3(0.36, 0.0, 0.0))
	_box(_sword_elbow, Vector3(0.32, 0.13, 0.14), Vector3(0.16, 0.0, 0.0), SKIN)
	_build_sword(_sword_elbow)

	_off_shoulder = _joint(_torso, "OffArm", Vector3(0.04, 0.5, 0.28))
	_box(_off_shoulder, Vector3(0.34, 0.15, 0.16), Vector3(0.17, 0.0, 0.0), coat_color)
	_box(_off_shoulder, Vector3(0.16, 0.13, 0.14), Vector3(0.38, 0.0, 0.0), SKIN)
	_pistol_mesh = _box(_off_shoulder, Vector3(0.3, 0.09, 0.07), Vector3(0.56, 0.02, 0.0), IRON)
	_pistol_mesh.visible = false

	_pose = POSES["waiting"].duplicate()
	_target_pose = POSES["waiting"].duplicate()
	_apply_pose()


func apply_state(state: String, action: String) -> void:
	_target_pose = POSES.get(_pose_name_for(state, action), POSES["guard"]).duplicate()
	_blend_speed = 12.0 if state == "stagger" else 9.0
	_strike_hold = 0.0
	if _pistol_mesh:
		_pistol_mesh.visible = state == "pistol_draw"


# The blow itself: snap to the extended pose, hold a beat, then let the normal
# blend take over. Called by the arena when a strike resolves, so what you see
# lands on the same frame the rules say it landed.
func play_strike(action: String) -> void:
	var height := ""
	match action:
		"chop":
			height = "high"
		"thrust":
			height = "mid"
		"slash":
			height = "low"
		_:
			return
	_pose = POSES["strike_%s" % height].duplicate()
	_target_pose = _pose.duplicate()
	_strike_hold = STRIKE_HOLD
	_apply_pose()


func advance(delta: float) -> void:
	_idle_phase += delta
	if _strike_hold > 0.0:
		_strike_hold -= delta
		return
	var weight := clampf(delta * _blend_speed, 0.0, 1.0)
	for key in _target_pose:
		_pose[key] = lerpf(float(_pose.get(key, 0.0)), float(_target_pose[key]), weight)
	_apply_pose()


func _apply_pose() -> void:
	if _body == null:
		return
	# A small breathing sway keeps the figures from reading as statues between
	# exchanges without touching the pose table.
	var sway := sin(_idle_phase * 1.9) * 0.012
	_body.position = Vector3(float(_pose.get("body_x", 0.0)), float(_pose.get("body_y", 0.0)) + sway, 0.0)
	_torso.rotation_degrees.z = float(_pose.get("torso", 0.0))
	_head.rotation_degrees.z = float(_pose.get("head", 0.0))
	_sword_shoulder.rotation_degrees.z = float(_pose.get("sword_arm", 0.0))
	_sword_elbow.rotation_degrees.z = float(_pose.get("forearm", 0.0))
	_off_shoulder.rotation_degrees.z = float(_pose.get("off_arm", 0.0))
	var stance := float(_pose.get("stance", 16.0))
	_leg_front.rotation_degrees.z = -stance * 0.5
	_leg_back.rotation_degrees.z = stance * 0.5


func _pose_name_for(state: String, action: String) -> String:
	match state:
		"windup":
			match action:
				"chop":
					return "windup_high"
				"thrust":
					return "windup_mid"
				"slash":
					return "windup_low"
			return "guard"
		"evade":
			return action
		"stagger":
			return "stagger"
		"taunt":
			return "taunt"
		"pistol_draw":
			return "pistol"
		"recover":
			return "recover"
		"yield":
			return "yield"
		"waiting":
			return "waiting"
	return "guard"


func _build_sword(parent: Node3D) -> void:
	_sword = _joint(parent, "Sword", Vector3(0.32, 0.0, 0.0))
	_box(_sword, Vector3(0.1, 0.16, 0.16), Vector3(0.03, 0.0, 0.0), HILT)
	_box(_sword, Vector3(0.86, 0.05, 0.09), Vector3(0.5, 0.0, 0.0), BLADE)


func _build_hat(parent: Node3D) -> void:
	match hat_style:
		"tricorn":
			_box(parent, Vector3(0.5, 0.06, 0.44), Vector3(0.0, 0.29, 0.0), Color(0.11, 0.09, 0.13))
			_box(parent, Vector3(0.28, 0.14, 0.26), Vector3(0.0, 0.34, 0.0), Color(0.11, 0.09, 0.13))
		"bandana":
			_box(parent, Vector3(0.29, 0.12, 0.3), Vector3(0.01, 0.27, 0.0), accent_color)
			_box(parent, Vector3(0.06, 0.08, 0.24), Vector3(-0.12, 0.24, 0.0), accent_color)
		_:
			_box(parent, Vector3(0.27, 0.1, 0.28), Vector3(0.0, 0.28, 0.0), Color(0.3, 0.22, 0.14))


func _joint(parent: Node3D, joint_name: String, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = at
	parent.add_child(joint)
	return joint


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color == BLADE:
		material.metallic = 0.7
		material.roughness = 0.25
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _parse_color(html: String, fallback: Color) -> Color:
	if Color.html_is_valid(html):
		return Color.html(html)
	return fallback
