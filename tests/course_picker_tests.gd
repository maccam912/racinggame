extends SceneTree
## Exercise real widgets and the host command boundary, without a network socket.
class CapturedClient extends NetworkClient:
	var sent: Array[Dictionary] = []
	func command(type: String, values: Dictionary = {}) -> void:
		sent.append({"type":type,"values":values.duplicate(true)})

var app: Node
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in range(8): await process_frame

func check_preview(view: CourseShowcase, index: int) -> void:
	assert(view.track==Catalog.tracks[index] and view.map.track==view.track)
	assert(view.photograph.texture.resource_path=="res://assets/exported/thumbnails/"+view.track.id+".png")
	assert(view.title.text==I18n.t(view.track.display_name_key))

func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await settle()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://reports/course-picker-"+label+".png")==OK)

func run() -> void:
	Catalog.load_all()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-picker.png"
	app.capture_frame = 1000000000
	root.add_child(app)
	await process_frame
	var folder := "user://tests/course-picker-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.menu.settings = app.data.settings
	app.data.profile.first_run_complete = true
	app.data.settings.reduce_motion = true
	var client := CapturedClient.new()
	client.guest_id = "host"
	client.process_mode = Node.PROCESS_MODE_DISABLED
	app.add_child(client)
	app.network = client
	var lobby := LobbyState.new()
	assert(not lobby.join("host","Driver",0).is_empty())
	assert(not lobby.join("friend","Friend",1,2,1).is_empty())
	var cases: Array[Dictionary] = []
	for mobile: bool in [false,true]:
		for scale: int in [100,150]:
			root.size = Vector2i(884,398) if mobile else Vector2i(1280,720)
			app.data.mobile = mobile
			app.menu.mobile_override = mobile
			app.menu.logical_unit_override = 1.0
			app.data.settings.ui_scale = scale
			client.lobby = lobby.public_state(0)
			app.lobby_page.show_rules()
			await settle()
			var course: CoursePicker = app.lobby_page.course_picker
			assert(course.picker.item_count==41)
			assert((course.picker.labels[0] if mobile else course.picker.get_item_text(0))==I18n.t("event.random_short"))
			for i in range(40):
				course.picker.item_selected.emit(i+1)
				assert(course.selected==i and course.picker.selected==i+1)
				check_preview(course.showcase,i)
				if mobile:
					await settle()
					assert(course.picker.get_global_rect().end.x<=app.menu.frame.get_global_rect().end.x+1,"every course name fits the compact selector")
					assert(course.showcase.map.get_global_rect().end.y<=app.menu.footer.get_parent().get_global_rect().position.y)
			app.lobby_page.track_shuffle.remaining.clear()
			var seen: Array[int] = [course.selected]
			for roll in range(39):
				var previous := course.selected
				course.picker.item_selected.emit(0)
				assert(course.selected!=previous and not course.selected in seen)
				seen.append(course.selected)
				check_preview(course.showcase,course.selected)
			assert(seen.size()==40)
			course.picker.item_selected.emit(0)
			var chosen := course.selected
			await settle()
			for node: Control in [course,course.picker,course.showcase.photograph,course.showcase.map]:
				assert(node.get_global_rect().position.x>=app.menu.frame.get_global_rect().position.x-1)
				assert(node.get_global_rect().end.x<=app.menu.frame.get_global_rect().end.x+1)
			if mobile:
				for view: Control in [course.showcase.photograph,course.showcase.map]:
					assert(view.get_global_rect().end.y<=app.menu.footer.get_parent().get_global_rect().position.y,"both views must be initially visible above the phone footer")
			await capture(("phone" if mobile else "desktop")+"-settings-"+str(scale))
			for button: Button in app.menu.footer.find_children("*","Button",true,false):
				if button.text==I18n.t("button.confirm"): button.pressed.emit()
			assert(client.sent[-1].type=="rules" and client.sent[-1].values.rules.track==chosen,"confirmation sends the exact previewed index without rerolling")
			assert(lobby.set_rules("host",client.sent[-1].values.rules))
			client.lobby = lobby.public_state(0)
			# Local hosted rooms also have sharing controls; they must not bury the views.
			app.iroh_rooms.authority = RoomServer.new()
			app.iroh_rooms.code = "TEST-ROOM"
			app.iroh_rooms.expires_at = Time.get_unix_time_from_system()+3600
			app.lobby_page.show_lobby()
			await settle()
			check_preview(app.menu.root.find_child("CourseShowcase",true,false),chosen)
			if mobile:
				var view: CourseShowcase = app.menu.root.find_child("CourseShowcase",true,false)
				assert(view.map.get_global_rect().end.y<=app.menu.footer.get_parent().get_global_rect().position.y)
				var y: float = app.menu.footer.get_child(0).get_global_rect().position.y
				for button: Control in app.menu.footer.get_children(): assert(absf(button.get_global_rect().position.y-y)<1)
			await capture(("phone" if mobile else "desktop")+"-lobby-"+str(scale))
			app.iroh_rooms.authority.wire.close()
			app.iroh_rooms.authority.free()
			app.iroh_rooms.authority = null
			# Cancelling another random choice leaves the authoritative room intact.
			app.lobby_page.show_rules()
			app.lobby_page.course_picker.choose(0)
			app.lobby_page.show_lobby()
			check_preview(app.menu.root.find_child("CourseShowcase",true,false),chosen)
			app.events.track_index = 0
			app.events.show_event()
			await settle()
			assert(app.events.random_card.get_parent().get_parent().get_index()==0)
			app.events.random_card.pressed.emit()
			await settle()
			assert(app.events.track_index!=0 and app.events.photograph.texture.resource_path.ends_with(Catalog.tracks[app.events.track_index].id+".png"))
			# Show the first entry for evidence; the chosen course remains previewed.
			app.events.random_card.grab_focus()
			await settle()
			await capture(("phone" if mobile else "desktop")+"-event-"+str(scale))
			cases.append({"mobile":mobile,"scale":scale,"manual":40,"random":40,"confirmed":chosen,"cancel_preserves_track":true})
	app.network = null
	client.queue_free()
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	var file := FileAccess.open("res://reports/course-picker-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"cases":cases,"boundary":"Actual widgets, all courses and full random tours, exact host command capture and LobbyState validation, cancel and lobby presentation. Native captures use desktop renderer; network transport covered separately."},"\t")+"\n")
	file.close()
	print("COURSE_PICKER_RANDOM_FIRST_PHOTOGRAPH_MAP_CONFIRM_CANCEL_PASS cases=",cases.size())
	quit()
