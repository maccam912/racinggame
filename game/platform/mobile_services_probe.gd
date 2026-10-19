extends Node
func _ready() -> void:
	if not OS.has_feature("android") or not Engine.has_singleton("PacificMobile"):
		push_error("PACIFIC_MOBILE_SERVICES_MISSING")
		get_tree().quit(1)
		return
	var bridge := Engine.get_singleton("PacificMobile")
	bridge.setActive(true)
	var deadline := Time.get_ticks_msec()+5000
	while int(bridge.getFocusState())!=1 and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	var focus := int(bridge.getFocusState())
	var kind := str(bridge.getRouteKind())
	if focus!=1 or not kind in ["wifi","cellular","ethernet","other","none","unknown"]:
		push_error("PACIFIC_MOBILE_SERVICES_PROBE_FAILED")
		get_tree().quit(1)
		return
	print("PACIFIC_MOBILE_SERVICES_READY "+JSON.stringify({"focus":focus,"route_kind":kind,"route_available":int(bridge.getRouteHandle())!=0}))
	bridge.setActive(false)
	await get_tree().create_timer(.25).timeout
	get_tree().quit()
