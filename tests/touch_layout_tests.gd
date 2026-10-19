extends SceneTree

func _initialize() -> void:
	var safe := Rect2(16,8,900,400)
	var base := TouchDriving.build_layout(safe,false,"slider",1.0,false)
	assert(TouchDriving.legal_layout(base,safe))
	var key := TouchLayoutBook.profile_key(safe,false,"slider",false)
	var book := TouchLayoutBook.with_profile({},key,base,safe)
	var restored := TouchLayoutBook.resolve(base,safe,book[key])
	assert(not restored.reset)
	for action: String in base:
		assert(base[action].position.distance_to(restored.controls[action].position)<.00001)
	var moved := base.duplicate()
	moved.steer.position.y-=32
	assert(TouchDriving.legal_layout(moved,safe))
	book = TouchLayoutBook.with_profile(book,key,moved,safe)
	assert(TouchLayoutBook.resolve(base,safe,book[key]).controls.steer.position.is_equal_approx(moved.steer.position))
	for bad: Variant in [false,42,{"steer":[NAN,.5]},{"brake":[1.1,.8]},{"steer":[.5]},{"steer":["x",.5]},{"steer":null}]:
		var invalid := TouchLayoutBook.resolve(base,safe,bad)
		assert(invalid.reset and invalid.controls==base)
	var overlap: Dictionary = book[key].duplicate(true)
	overlap.brake = overlap.steer
	assert(TouchLayoutBook.resolve(base,safe,overlap).reset)
	var edge: Dictionary = book[key].duplicate(true)
	edge.steer = [0.0,0.0]
	var clamped := TouchLayoutBook.resolve(base,safe,edge)
	assert(not clamped.reset and clamped.controls.steer.get_center().x>=safe.position.x+91)
	for point: Vector2 in [Vector2(-999,-999),Vector2(9999,9999),Vector2(333,271)]:
		var snapped := TouchLayoutBook.snapped_center(safe,point,base.steer.size,"steer")
		assert((snapped-safe.position).is_equal_approx((snapped-safe.position).snapped(Vector2.ONE*8)),"drag clamps stay on the 8-point grid")
		assert(TouchDriving.clamp_center(safe,snapped,base.steer.size,"steer").is_equal_approx(snapped))
	var tiny := base.duplicate()
	tiny.brake = Rect2(base.brake.position,Vector2(40,40))
	assert(not TouchDriving.legal_layout(tiny,safe),"minimum hit targets enforced")
	var keys: Dictionary = {}
	for dimensions: Vector2 in [Vector2(900,400),Vector2(400,900),Vector2(1200,800),Vector2(800,1200)]:
		for automatic: bool in [true,false]:
			for steering: String in ["slider","buttons"]:
				for mirror: bool in [false,true]:
					var profile := TouchLayoutBook.profile_key(Rect2(Vector2.ZERO,dimensions),automatic,steering,mirror)
					assert(not keys.has(profile))
					keys[profile]=true
	assert(keys.size()==32,"orientation, device class and control variants remain independent")
	var folder := "user://tests/touch-layout-"+str(Time.get_ticks_usec())
	var data := AppData.new(folder,true)
	data.settings.touch_layouts = book
	assert(data.save_settings()==OK)
	var cold := AppData.new(folder,true)
	var cold_layout := TouchLayoutBook.resolve(base,safe,cold.settings.touch_layouts[key])
	assert(not cold_layout.reset)
	for action: String in moved:
		assert(cold_layout.controls[action].position.distance_to(moved[action].position)<.00001)
	var touch := TouchDriving.new()
	touch.size = Vector2(1350,600)
	touch.auto_accelerate = false
	var geometry := TouchDriving.safe_geometry(touch.size)
	var actual_key := TouchLayoutBook.profile_key(geometry.safe,false,"slider",false)
	touch.layouts = {actual_key:{"steer":["bad",0]}}
	var notices: Array[String] = []
	touch.layout_reset.connect(func(profile: String) -> void: notices.append(profile))
	touch.rebuild()
	touch.rebuild()
	assert(notices==[actual_key] and touch.layout_supported,"invalid layout emits one reset notice")
	touch.free()
	print("Touch layouts: normalized cold reload, independent variants, clamping, malformed/overlapping centers, minimum targets and one-time reset notice pass")
	quit()
