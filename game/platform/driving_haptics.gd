class_name DrivingHaptics
extends RefCounted
## Motor commands are input-device feedback, never a simulation dependency.
var elapsed: float = 0
var device: int = -1
var last_strength := Vector2.ZERO
var strong: float = 0
var strong_until: float = 0
var collision_until: float = 0
var landing_until: float = 0
var last_snapshot: int = -1
var feedback_cursor: int = 0
static var last_touch_collision: int = -1000
static var last_touch_ui: int = -1000

func connected(id: int) -> bool: return Input.get_connected_joypads().has(id)
func send_start(id: int, weak: float, heavy: float, duration: float) -> void: Input.start_joy_vibration(id,weak,heavy,duration)
func send_stop(id: int) -> void: Input.stop_joy_vibration(id)

func update(drive: RaceDrive, settings: Dictionary, dt: float, suspended: bool) -> void:
	elapsed += dt
	var owner := drive.driver
	var next_device := owner.joy_device if owner.owner_device=="gamepad" and owner.focused and not suspended and connected(owner.joy_device) else -1
	if device!=next_device:
		stop()
		device = next_device
	var state := drive.state
	var events: Array[String] = []
	if drive.network==null: events.assign(state.events)
	if drive.network:
		for event_state: VehicleState in drive.network.feedback_since(feedback_cursor):
			if event_state.slot==drive.local_slot: events.append_array(event_state.events)
		feedback_cursor = drive.network.feedback_sequence
	if not suspended and owner.focused:
		if ("wall" in events or "bump" in events) and elapsed>=collision_until:
			collision_until = elapsed+.15
			strong = .4
			strong_until = elapsed+.12
			touch("collision",settings,drive.touch.visible)
		elif "land" in events and elapsed>=landing_until:
			landing_until = elapsed+.5
			strong = .3
			strong_until = elapsed+.15
	if device<0: return
	var amount := clampf(float(settings.vibration)/100,0,1)
	var weak := .15*amount if state.drift_phase==1 and state.grounded and state.speed()>5 else 0.0
	var heavy := strong*amount if elapsed<strong_until else 0.0
	var desired := Vector2(weak,heavy)
	if desired==last_strength: return
	last_strength = desired
	if desired==Vector2.ZERO: send_stop(device)
	else: send_start(device,weak,heavy,maxf(.001,strong_until-elapsed) if heavy>0 else 0.0)

func stop() -> void:
	if device>=0: send_stop(device)
	device = -1
	last_strength = Vector2.ZERO
	strong_until = 0

static func touch(kind: String, settings: Dictionary, mobile: bool) -> void:
	if not mobile or not OS.has_feature("mobile") or not bool(settings.get("haptics",false)): return
	var now := Time.get_ticks_msec()
	if kind=="collision":
		if now-last_touch_collision<250: return
		last_touch_collision = now
		Input.vibrate_handheld(40,.5)
	else:
		if now-last_touch_ui<80: return
		last_touch_ui = now
		Input.vibrate_handheld(12,.2)
