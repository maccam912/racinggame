extends SceneTree
var failures: int = 0

func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		print("TEST FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	var folder := "user://tests/display-"+str(Time.get_ticks_usec())
	app.data = AppData.new(folder,false)
	app.data.settings.window_mode = "windowed"
	app.data.save_settings()
	var page: SettingsPage = app.settings_page
	page.show_tab("display",app.show_menu)
	page.begin_display("window_mode","fullscreen")
	check(app.data.settings.window_mode=="fullscreen" and not page.pending_display.is_empty(),"display change previews without commitment")
	check(AppData.new(folder,false).settings.window_mode=="windowed","unconfirmed display change is not saved")
	check(page.revert_timer.wait_time==15,"confirmation lasts fifteen seconds")
	app.show_menu()
	await process_frame
	await process_frame
	check(app.data.settings.window_mode=="windowed" and page.pending_display.is_empty(),"destroying the dialog during screen navigation reverts")
	page.show_tab("display",app.show_menu)
	page.begin_display("window_mode","fullscreen")
	page.revert_timer.timeout.emit()
	await process_frame
	await process_frame
	check(app.data.settings.window_mode=="windowed","timeout reverts")
	page.begin_display("window_mode","fullscreen")
	page.display_modal.close_requested.emit()
	await process_frame
	await process_frame
	check(app.data.settings.window_mode=="windowed","closing confirmation reverts")
	page.begin_display("window_mode","fullscreen")
	page.display_modal.confirmed.emit()
	await process_frame
	await process_frame
	check(app.data.settings.window_mode=="fullscreen" and AppData.new(folder,false).settings.window_mode=="fullscreen","Keep persists confirmed mode")
	app.data.settings.window_mode = "windowed"
	app.data.save_settings()
	app.data.store.fail_stage = "before_replace"
	app.data.store.fail_component = "settings"
	page.begin_display("window_mode","fullscreen")
	page.display_modal.confirmed.emit()
	await process_frame
	await process_frame
	check(app.data.settings.window_mode=="windowed" and AppData.new(folder,false).settings.window_mode=="windowed","failed Keep write reverts and preserves prior save")
	check(page.status.text==I18n.t("data.save_failed"),"failed Keep is visible")
	app.data.store.fail_stage = ""
	app.data.settings.frame_cap = 30
	app.data.settings.ui_scale = 150
	app.data.settings.master = 35
	app.data.save_settings()
	page.restore_this_tab()
	check(app.data.settings.window_mode=="borderless" and not page.pending_display.is_empty(),"Restore Display uses confirmation too")
	check(AppData.new(folder,false).settings.window_mode=="windowed","Restore does not save its trial mode")
	app.data.settings.master = 40
	page.revert_display()
	await process_frame
	await process_frame
	check(app.data.settings.window_mode=="windowed" and app.data.settings.frame_cap==30 and app.data.settings.ui_scale==150,"Restore cancellation restores the entire display tab")
	check(app.data.settings.master==40,"display rollback preserves unrelated preferences")
	page.begin_display("window_mode","fullscreen")
	var old_generation := page.display_generation
	page.begin_display("window_mode","borderless")
	page.finish_display(false,old_generation)
	await process_frame
	check(app.data.settings.window_mode=="borderless" and not page.pending_display.is_empty(),"stale callbacks cannot cancel a newer display trial")
	page.revert_display()
	await process_frame
	await process_frame
	var held_data: AppData = app.data
	page.begin_display("window_mode","fullscreen")
	app.queue_free()
	await process_frame
	await process_frame
	check(held_data.settings.window_mode=="windowed","app teardown rolls back pending display changes without rebuilding UI")
	print("Display transaction fixtures: %d failures" % failures)
	quit(1 if failures else 0)
