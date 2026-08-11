extends Resource
class_name ShipStats

@export var ship_type_id: String = ""
@export var display_name: String = ""
@export var modification_ids: Array[String] = []
@export var modification_names: Array[String] = []
@export var visual_scale: float = 1.0
@export var visual_profile_id: String = ""
@export var max_speed: float = 9.0
@export var acceleration: float = 3.8
@export var deceleration: float = 2.6
@export var turn_rate: float = 70.0
@export var minimum_turn_rate: float = 18.0
@export var sail_trim_speed: float = 0.65
@export var max_hull: float = 80.0
@export var max_sail: float = 80.0
@export var max_crew: float = 80.0
@export var starting_crew: float = 80.0
@export var max_morale: float = 100.0
@export var magazine_explosion_multiplier: float = 1.0
@export var usable_load_capacity: float = 90.0
@export var gun_ports: int = 14
@export var gun_ports_per_side: int = 7
@export var cargo_weight: float = 0.0
@export var cannon_weight: float = 0.0
@export var total_load_weight: float = 0.0
@export var load_fraction: float = 0.0
@export var load_speed_multiplier: float = 1.0
@export var load_turn_multiplier: float = 1.0
