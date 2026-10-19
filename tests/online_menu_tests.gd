extends SceneTree

var app: Node
func _initialize() -> void:
	call_deferred("run_tests")

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func run_tests() -> void:
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await settle()
	app.data.mobile = false
	app.show_online()
	await settle()
	assert(app.page=="online" and app.online_page.hub_buttons.size()==4)
	for button: Button in app.online_page.hub_buttons:
		assert(button.disabled,"No hosted endpoints have been configured")
	var direct := false
	for button: Button in app.menu.root.find_children("*","Button",true,false):
		if button.text==I18n.t("online.direct"):
			direct = true
			assert(not button.disabled)
	assert(direct)
	app.online_page.show_create()
	await settle()
	var name_edit: LineEdit = app.menu.root.find_child("room_name",true,false)
	assert(name_edit!=null and app.menu.root.find_child("create_room_start",true,false).disabled)
	name_edit.text = "<bad>"
	name_edit.text_changed.emit(name_edit.text)
	app.online_page.create_room()
	assert(app.online_page.status.text==I18n.t("online.room_name_error"))
	app.online_page.draft.rules.track = 5
	app.online_page.draft.rules.laps = 3
	app.online_page.show_create()
	await settle()
	assert(app.online_page.draft.rules.track==5 and app.online_page.draft.rules.laps==3)
	app.online_page.show_code()
	await settle()
	var code: LineEdit = app.menu.root.find_child("room_code",true,false)
	assert(code!=null and app.menu.root.find_child("join_code_start",true,false).disabled)
	code.text = "bad"
	code.text_submitted.emit(code.text)
	assert(app.online_page.status.text==I18n.t("online.code_error"))
	# Fake only region availability; no live request is made before cancelling.
	app.regions.regions.assign([{"id":"test","name_key":"online.test","url":"https://localhost:29999","available":true,"ping_ms":12.0,"samples":[12.0,13.0,10.0],"finished":true}])
	app.regions.last_probe_ms = Time.get_ticks_msec()
	app.online_page.show_hub(false)
	await settle()
	for button: Button in app.online_page.hub_buttons: assert(not button.disabled)
	app.online_page.browse()
	assert(app.page=="online_rooms" and app.directory_client.busy())
	app.directory_client.cancel()
	app.online_page.pending = ""
	var a := {"id":RaceSetup.uuid(),"name":"Empty Room","region":"test","rules":{"track":0,"laps":2,"bot_fill":true,"difficulty":1,"contact":true},"humans":0,"capacity":8,"state":"Lobby","created_at":100}
	var b := a.duplicate(true)
	b.id = RaceSetup.uuid()
	b.name = "Busy Room"
	b.humans = 4
	b.created_at = 200
	assert(OnlinePage.quick_order(b,a))
	var c := b.duplicate(true)
	c.id = RaceSetup.uuid()
	c.created_at = 150
	assert(OnlinePage.quick_order(c,b))
	app.online_page.rooms.assign([a,b,c])
	app.online_page.render_rooms()
	await settle()
	assert(app.online_page.room_list.find_children("join_*","Button",true,false).size()==3)
	app.online_page.rooms[0].state = "InRace"
	app.online_page.rooms[1].humans = 8
	app.online_page.render_rooms()
	await settle()
	assert(app.online_page.room_list.find_children("join_*","Button",true,false).size()==1)
	app.online_page.only_available = false
	app.online_page.show_in_race = true
	app.online_page.render_rooms()
	await settle()
	var joins: Array[Node] = app.online_page.room_list.find_children("join_*","Button",true,false)
	assert(joins.size()==3)
	var disabled := 0
	for button: Button in joins:
		if button.disabled: disabled += 1
	assert(disabled==2)
	app.online_page.begin_action("quick")
	assert(app.page=="online_wait")
	app.online_page.connect_deadline = Time.get_ticks_msec()-1
	await settle()
	assert(app.page=="online_error" and not app.directory_client.busy())
	app.online_page.exit_to_hub()
	app.online_page.begin_action("quick")
	app.show_menu()
	await settle()
	assert(app.page=="main" and app.online_page.pending.is_empty() and not app.directory_client.busy())
	app.queue_free()
	await settle()
	print("ONLINE_MENU_UNAVAILABLE_CREATE_CODE_BROWSER_FILTER_CANCEL_TIMEOUT_PASS")
	await create_timer(.5).timeout # Retire stopped audio on the mixer thread.
	quit()
