class_name FlatQuery
extends RefCounted
## Deterministic no-engine fixtures and server/controller unit tests.

var normal := Vector3.UP
var height: float = 0.0
var surface: String = "asphalt"


func ground(state: VehicleState) -> Dictionary:
	return {"supported": state.position.y <= height + 1.0, "height": height, "normal": normal, "surface": surface}


func sweep(position: Vector3, velocity: Vector3, _yaw: float, dt: float, _new_impact: bool) -> Dictionary:
	return {"position": position + velocity * dt, "velocity": velocity, "hit": false, "separated": true}
