class_name BindingCapture
extends ConfirmationDialog

signal selected(value: Dictionary)
signal expired

var device_name: String = "keyboard"
var opened: int = 0
var deadline: int = 0
var done: bool = false
var baselines: Dictionary = {}

func _ready() -> void:
	opened=Time.get_ticks_msec()
	deadline=opened+10000
	for device: int in Input.get_connected_joypads():
		for axis: int in range(JOY_AXIS_MAX):
			baselines["%d:%d" % [device,axis]]=Input.get_joy_axis(device,axis)
	get_ok_button().hide()
	cancel_button_text=I18n.t("button.cancel")
	title=I18n.t("binding.capture_title")
	dialog_autowrap=true
	update_caption()
	popup_centered(Vector2i(620,200))

func _process(_dt: float) -> void:
	if done:
		return
	if Time.get_ticks_msec()>=deadline:
		done=true
		expired.emit()
	else:
		update_caption()

func update_caption() -> void:
	dialog_text=I18n.t("binding.capture",[maxi(0,ceili((deadline-Time.get_ticks_msec())/1000.0))])

func _input(event: InputEvent) -> void:
	if done or not visible:
		return
	if event is InputEventKey and event.pressed and (event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE) or event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_BACK:
		get_viewport().set_input_as_handled()
		done=true
		canceled.emit()
		return
	if Time.get_ticks_msec()-opened<200:
		if event is InputEventJoypadMotion:
			baselines["%d:%d" % [event.device,event.axis]]=event.axis_value
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	var value: Variant=BindingBook.from_event(event,device_name)
	if value==null:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		var key: String="%d:%d" % [event.device,event.axis]
		var previous: float=float(baselines.get(key,0.0))
		baselines[key]=event.axis_value
		if absf(event.axis_value-previous)<.2:
			return
	get_viewport().set_input_as_handled()
	done=true
	selected.emit(value)
