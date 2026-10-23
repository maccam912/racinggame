class_name BindingBook
extends RefCounted
## Two serializable slots per action/device, with conflicts scoped to the active
## driving or menu context. Runtime InputEvents never enter settings JSON.

const DRIVING := ["steer_left","steer_right","accelerate","brake","boost","handbrake","recover","camera","look_back","pause"]
const MENU := ["ui_up","ui_down","ui_left","ui_right","ui_accept","ui_cancel"]
static var initialized: bool = false
static var applied_hash: String = ""

static func actions() -> Array:
	return DRIVING + MENU

static func key(code: int) -> Dictionary:
	return {"kind":"key","code":code}

static func button(index: int) -> Dictionary:
	return {"kind":"button","button":index}

static func axis(index: int,direction: int) -> Dictionary:
	return {"kind":"axis","axis":index,"direction":direction}

static func defaults() -> Dictionary:
	var keyboard := {"steer_left":[key(KEY_A),key(KEY_LEFT)],"steer_right":[key(KEY_D),key(KEY_RIGHT)],"accelerate":[key(KEY_W),key(KEY_UP)],"brake":[key(KEY_S),key(KEY_DOWN)],"boost":[key(KEY_SHIFT),null],"handbrake":[key(KEY_SPACE),null],"recover":[key(KEY_R),null],"camera":[key(KEY_C),null],"look_back":[key(KEY_V),null],"pause":[key(KEY_ESCAPE),null],"ui_up":[key(KEY_UP),key(KEY_W)],"ui_down":[key(KEY_DOWN),key(KEY_S)],"ui_left":[key(KEY_LEFT),key(KEY_A)],"ui_right":[key(KEY_RIGHT),key(KEY_D)],"ui_accept":[key(KEY_ENTER),null],"ui_cancel":[key(KEY_ESCAPE),null]}
	var pad := {"steer_left":[axis(JOY_AXIS_LEFT_X,-1),null],"steer_right":[axis(JOY_AXIS_LEFT_X,1),null],"accelerate":[axis(JOY_AXIS_TRIGGER_RIGHT,1),null],"brake":[axis(JOY_AXIS_TRIGGER_LEFT,1),null],"boost":[button(JOY_BUTTON_X),null],"handbrake":[button(JOY_BUTTON_A),null],"recover":[button(JOY_BUTTON_Y),null],"camera":[button(JOY_BUTTON_B),null],"look_back":[button(JOY_BUTTON_RIGHT_STICK),null],"pause":[button(JOY_BUTTON_START),null],"ui_up":[button(JOY_BUTTON_DPAD_UP),axis(JOY_AXIS_LEFT_Y,-1)],"ui_down":[button(JOY_BUTTON_DPAD_DOWN),axis(JOY_AXIS_LEFT_Y,1)],"ui_left":[button(JOY_BUTTON_DPAD_LEFT),axis(JOY_AXIS_LEFT_X,-1)],"ui_right":[button(JOY_BUTTON_DPAD_RIGHT),axis(JOY_AXIS_LEFT_X,1)],"ui_accept":[button(JOY_BUTTON_A),null],"ui_cancel":[button(JOY_BUTTON_B),null]}
	return {"keyboard":keyboard,"gamepad":pad}

static func valid_binding(value: Variant,device_name: String) -> bool:
	if value==null:
		return true
	if not value is Dictionary:
		return false
	if device_name=="keyboard":
		if value.size()!=2 or value.get("kind")!="key" or not NetEvents.integer(value.get("code"),1,8388607):
			return false
		var caption := OS.get_keycode_string(int(value.code))
		return caption!="" and OS.find_keycode_from_string(caption)==int(value.code)
	if device_name!="gamepad":
		return false
	if value.get("kind")=="button":
		return value.size()==2 and NetEvents.integer(value.get("button"),0,JOY_BUTTON_MAX-1)
	if value.get("kind")=="axis":
		return value.size()==3 and NetEvents.integer(value.get("axis"),0,JOY_AXIS_MAX-1) and NetEvents.integer(value.get("direction"),-1,1) and int(value.direction)!=0
	return false

static func same(a: Variant,b: Variant) -> bool:
	return a!=null and b!=null and a==b

static func sanitize(saved: Dictionary) -> Dictionary:
	var result := defaults()
	for device_name: String in ["keyboard","gamepad"]:
		var source: Variant = saved.get(device_name,{})
		if not source is Dictionary:
			continue
		for action: String in actions():
			var entries: Variant = source.get(action)
			if not entries is Array or entries.size()!=2 or not valid_binding(entries[0],device_name) or not valid_binding(entries[1],device_name) or same(entries[0],entries[1]):
				continue
			result[device_name][action]=entries.duplicate(true)
		for context: Array in [DRIVING,MENU]:
			var conflict := false
			var prior: Array = []
			for action: String in context:
				for entry: Variant in result[device_name][action]:
					if entry!=null:
						if prior.has(entry):
							conflict=true
						prior.append(entry)
			if conflict:
				var original: Dictionary = defaults()[device_name]
				for action: String in context:
					result[device_name][action]=original[action].duplicate(true)
	for action: String in ["ui_accept","ui_cancel"]:
		if result.keyboard[action]==[null,null]:
			result.keyboard[action]=defaults().keyboard[action]
	return result

static func essential(book: Dictionary) -> bool:
	return book.keyboard.ui_accept!=[null,null] and book.keyboard.ui_cancel!=[null,null]

static func change(saved: Dictionary,device_name: String,action: String,slot: int,value: Variant,decision: String = "") -> Dictionary:
	if device_name not in ["keyboard","gamepad"] or action not in actions() or slot not in [0,1] or not valid_binding(value,device_name):
		return {"status":"invalid"}
	var book := sanitize(saved)
	var previous: Variant = book[device_name][action][slot]
	var conflict_action := ""
	var conflict_slot := -1
	for other: String in (DRIVING if action in DRIVING else MENU):
		for index in range(2):
			if not (action==other and index==slot) and same(value,book[device_name][other][index]):
				conflict_action=other
				conflict_slot=index
	if conflict_action!="":
		if decision=="":
			return {"status":"conflict","action":conflict_action,"slot":conflict_slot}
		if decision not in ["swap","replace"]:
			return {"status":"canceled"}
		book[device_name][conflict_action][conflict_slot]=previous if decision=="swap" else null
	book[device_name][action][slot]=value.duplicate(true) if value is Dictionary else null
	if not essential(book):
		return {"status":"essential"}
	return {"status":"ok","bindings":book}

static func event_for(value: Dictionary) -> InputEvent:
	var event: InputEvent
	match value.kind:
		"key":
			event=InputEventKey.new()
			event.physical_keycode=int(value.code)
		"button":
			event=InputEventJoypadButton.new()
			event.button_index=int(value.button)
		"axis":
			event=InputEventJoypadMotion.new()
			event.axis=int(value.axis)
			event.axis_value=float(value.direction)
	event.device=-1
	return event

static func apply(saved: Dictionary) -> void:
	var book := sanitize(saved)
	var fingerprint := JSON.stringify(book).sha256_text()
	if initialized and fingerprint==applied_hash:
		return
	for action: String in actions():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action,.5 if action in MENU else 0.0)
		for device_name: String in ["keyboard","gamepad"]:
			for value: Variant in book[device_name][action]:
				if value is Dictionary:
					InputMap.action_add_event(action,event_for(value))
	initialized=true
	applied_hash=fingerprint

static func ensure_defaults() -> void:
	if not initialized:
		apply({})

static func from_event(event: InputEvent,device_name: String) -> Variant:
	if device_name=="keyboard" and event is InputEventKey and event.pressed and not event.echo:
		var code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		var result:=key(code)
		return result if valid_binding(result,device_name) else null
	if device_name=="gamepad" and event is InputEventJoypadButton and event.pressed:
		return button(event.button_index) if event.button_index>=0 and event.button_index<JOY_BUTTON_MAX else null
	if device_name=="gamepad" and event is InputEventJoypadMotion and absf(event.axis_value)>=.6:
		return axis(event.axis,int(signf(event.axis_value))) if event.axis>=0 and event.axis<JOY_AXIS_MAX else null
	return null

static func caption(value: Variant,icons: String = "auto") -> String:
	if value==null:
		return I18n.t("binding.empty")
	if value.kind=="key":
		return OS.get_keycode_string(int(value.code))
	if value.kind=="button":
		var faces := {JOY_BUTTON_A:["A","Cross"],JOY_BUTTON_B:["B","Circle"],JOY_BUTTON_X:["X","Square"],JOY_BUTTON_Y:["Y","Triangle"]}
		if faces.has(int(value.button)):
			var labels: Array = faces[int(value.button)]
			return labels[0] if icons=="xbox" else labels[1] if icons=="playstation" else "%s / %s" % labels
		var names := {JOY_BUTTON_BACK:"view",JOY_BUTTON_GUIDE:"guide",JOY_BUTTON_START:"menu",JOY_BUTTON_LEFT_STICK:"left_click",JOY_BUTTON_RIGHT_STICK:"right_click",JOY_BUTTON_LEFT_SHOULDER:"left_shoulder",JOY_BUTTON_RIGHT_SHOULDER:"right_shoulder",JOY_BUTTON_DPAD_UP:"dpad_up",JOY_BUTTON_DPAD_DOWN:"dpad_down",JOY_BUTTON_DPAD_LEFT:"dpad_left",JOY_BUTTON_DPAD_RIGHT:"dpad_right"}
		return I18n.t("binding."+names[int(value.button)]) if names.has(int(value.button)) else I18n.t("binding.button",[int(value.button)+1])
	var axes := {JOY_AXIS_LEFT_X:"left_x",JOY_AXIS_LEFT_Y:"left_y",JOY_AXIS_RIGHT_X:"right_x",JOY_AXIS_RIGHT_Y:"right_y",JOY_AXIS_TRIGGER_LEFT:"left_trigger",JOY_AXIS_TRIGGER_RIGHT:"right_trigger"}
	return I18n.t("binding."+axes[int(value.axis)]+("_positive" if int(value.direction)>0 else "_negative")) if axes.has(int(value.axis)) else I18n.t("binding.axis",[int(value.axis)+1,"+" if int(value.direction)>0 else "−"])
