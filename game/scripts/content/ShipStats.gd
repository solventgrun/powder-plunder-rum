extends Resource
class_name ShipStats

@export var ship_type_id: String = ""
@export var display_name: String = ""
@export var modification_ids: Array[String] = []
@export var modification_names: Array[String] = []
@export var visual_scale: float = 1.0
@export var max_speed: float = 9.0
@export var acceleration: float = 3.8
@export var deceleration: float = 2.6
@export var turn_rate: float = 70.0
@export var max_hull: float = 80.0
@export var magazine_explosion_multiplier: float = 1.0
@export var max_cannons_per_side: int = 5
@export var cannon_weight_capacity: float = 6500.0
