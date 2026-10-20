extends SceneTree

func _initialize() -> void:
	var defaults := BindingBook.defaults()
	assert(BindingBook.sanitize({})==defaults)
	var conflict := BindingBook.change({},"keyboard","accelerate",0,BindingBook.key(KEY_S))
	assert(conflict.status=="conflict" and conflict.action=="brake")
	var swapped := BindingBook.change({},"keyboard","accelerate",0,BindingBook.key(KEY_S),"swap")
	assert(swapped.status=="ok" and swapped.bindings.keyboard.accelerate[0]==BindingBook.key(KEY_S) and swapped.bindings.keyboard.brake[0]==BindingBook.key(KEY_W))
	var replaced := BindingBook.change({},"keyboard","accelerate",0,BindingBook.key(KEY_S),"replace")
	assert(replaced.status=="ok" and replaced.bindings.keyboard.brake[0]==null)
	assert(BindingBook.change({},"keyboard","ui_accept",0,null).status=="essential")
	var second := BindingBook.change({},"keyboard","ui_accept",1,BindingBook.key(KEY_F))
	assert(second.status=="ok")
	var cleared := BindingBook.change(second.bindings,"keyboard","ui_accept",0,null)
	assert(cleared.status=="ok")
	assert(BindingBook.change(cleared.bindings,"keyboard","ui_accept",1,null).status=="essential")
	assert(BindingBook.change({},"keyboard","ui_cancel",0,null).status=="essential")
	# A driving binding may share a key with the separate menu context.
	assert(BindingBook.change({},"keyboard","recover",0,BindingBook.key(KEY_ENTER)).status=="ok")
	var corrupted := defaults.duplicate(true)
	corrupted.keyboard.recover=[BindingBook.key(KEY_W),null]
	assert(BindingBook.sanitize(corrupted).keyboard.recover==defaults.keyboard.recover)
	corrupted=defaults.duplicate(true)
	corrupted.keyboard.ui_cancel=[null,null]
	assert(BindingBook.sanitize(corrupted).keyboard.ui_cancel==defaults.keyboard.ui_cancel)
	assert(not BindingBook.valid_binding({"kind":"key","code":1,"script":"evil"},"keyboard"))
	assert(not BindingBook.valid_binding({"kind":"axis","axis":0,"direction":0},"gamepad"))
	assert(not BindingBook.valid_binding({"kind":"button","button":-1},"gamepad"))
	var remapped := BindingBook.change({},"keyboard","accelerate",0,BindingBook.key(KEY_E))
	assert(remapped.status=="ok")
	BindingBook.apply(remapped.bindings)
	assert(InputMap.action_has_event("accelerate",BindingBook.event_for(BindingBook.key(KEY_E))))
	assert(not InputMap.action_has_event("accelerate",BindingBook.event_for(BindingBook.key(KEY_W))))
	var folder := "user://tests/bindings-"+RaceSetup.uuid()
	var data := AppData.new(folder,false)
	data.settings.bindings=remapped.bindings
	assert(data.save_settings()==OK)
	var loaded := AppData.new(folder,false)
	BindingBook.apply(loaded.settings.bindings)
	var event := InputEventKey.new()
	event.physical_keycode=KEY_E
	event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var driver := DrivingInput.new()
	assert(driver.sample(true).throttle==1)
	var release := event.duplicate() as InputEventKey
	release.pressed=false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	assert(driver.sample(true).throttle==0)
	BindingBook.apply({})
	print("Binding contracts: conflicts, swap/replace, essential keyboard paths, contexts, corruption and cold-loaded physical input pass")
	quit()
