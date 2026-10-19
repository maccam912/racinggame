class_name CarDefinition
extends Resource

@export var id: String
@export var display_name_key: String
@export var top_speed: float
@export var acceleration: float
@export var grip: float
@export var turn_factor: float
@export var default_paint: int
@export var role: String


static func from_data(data: Dictionary) -> CarDefinition:
	var car := CarDefinition.new()
	for key in ["id", "display_name_key", "top_speed", "acceleration", "grip", "turn_factor", "default_paint", "role"]:
		car.set(key, data[key])
	return car
