class_name VehicleState
extends RefCounted

var slot: int = 0
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var yaw: float = 0.0
var yaw_rate: float = 0.0
var ground_normal := Vector3.UP
var grounded: bool = true
var steer_filter: float = 0.0
var drift_phase: int = 0 # Grip, Drift, Recovering grip
var drift_timer: float = 0.0
var drift_entry: float = 0.0
var reverse_hold: float = 0.0
var reversing: bool = false
var boost_charges: int = 0
var boost_ticks: int = 0
var boost_latched: int = 0 # Integer so the authoritative snapshot is exact.
var braking: bool = false # Authoritative lamp state; no additional controller force.
var wall_separation_ticks: int = 12
var wall_contact: bool = false
var contact_ticks: int = 0
var race_role: int = 0 # 0: standard, 1: leader, 2: chasing (authoritative).
# Authority-only race recovery anchors. Local archives preserve these; UDP
# prediction receives the resulting pose/progress through the existing snapshot.
var recovery_rank: int = -1
var recovery_progress: float = -1.0
var recovery_speed: float = 0.0 # Shared rolling speed at fade completion.
var recovery_ticks: int = 0
var recovery_hold_ticks: int = 0
var recovery_latched: bool = false
var ghost_ticks: int = 0
var offroad_ticks: int = 0
var outside_ticks: int = 0
var wrong_way_ticks: int = 0
var forward_ticks: int = 0
var launch_ticks: int = 0
var jump_lap: int = -1 # Protocol 6: lap*8 plus the three consumed ramp bits.
var route_s: float = -1.0
var last_gate: int = -1
var laps: int = 0
var last_ack: int = 0
var finished: bool = false
var finish_time: float = -1.0
var trial_valid: bool = true
var lap_valid: bool = true
var lap_start_time: float = 0.0
var last_lap_time: float = -1.0
var best_lap_time: float = -1.0
var distance_m: float = 0.0
var backwards_m: float = 0.0
var dnf_reason: String = ""
var surface: String = "asphalt"
var events: Array[String] = []


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, -cos(yaw))


func speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func copy() -> VehicleState:
	var result := VehicleState.new()
	for property: Dictionary in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = get(property.name)
			result.set(property.name, value.duplicate() if value is Array else value)
	return result
