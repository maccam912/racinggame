extends SceneTree
## Cold restart, defaults, malformed optional preferences, and Trial isolation.
class Owner extends Node:
	var data: AppData
	var requested: Dictionary
	func request_drive(configuration: Dictionary, _back: Callable) -> void:
		requested = configuration
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var folder := "user://tests/quick-setup-"+RaceSetup.uuid()
	var owner := Owner.new()
	owner.data = AppData.new(folder,false)
	var menu := EventMenu.new(owner)
	assert(menu.laps==2 and menu.opponents==7 and menu.difficulty==1 and menu.contact)
	menu.laps = 1
	menu.opponents = 3
	menu.difficulty = 3
	menu.contact = false
	menu.track_index = 9
	menu.filter_index = EventMenu.FILTERS.find("smooth")
	menu.start()
	assert(owner.requested.laps==1 and owner.requested.opponents==3 and not owner.requested.contact)
	owner.data = AppData.new(folder,false)
	menu = EventMenu.new(owner)
	assert(menu.laps==1 and menu.opponents==3 and menu.difficulty==3 and not menu.contact)
	assert(menu.track_index==9 and EventMenu.FILTERS[menu.filter_index]=="smooth")
	var before: Dictionary = owner.data.profile.quick_setup.duplicate(true)
	menu.mode = "trial"
	menu.track_index = 3
	menu.filter_index = 0
	menu.start()
	assert(owner.requested.laps==1 and owner.requested.opponents==0)
	assert(owner.data.profile.quick_setup==before,"Trial never replaces Quick Race preferences")
	menu.mode = "quick"
	owner.data.store.fail_component = "profile"
	owner.data.store.fail_stage = "before_replace"
	menu.opponents = 2
	assert(menu.remember_setup()!=OK and owner.data.store.notices.has("data.save_failed"))
	owner.data = AppData.new(folder,false)
	assert(owner.data.profile.quick_setup==before,"failed preference writes preserve the last durable setup")
	owner.data.profile.quick_setup = {"laps":99,"opponents":-2,"difficulty":"easy","contact":"no","track":"removed_course","filter":"removed_filter"}
	assert(owner.data.save_profile()==OK)
	owner.data = AppData.new(folder,false)
	menu = EventMenu.new(owner)
	assert(menu.laps==2 and menu.opponents==7 and menu.difficulty==1 and menu.contact)
	assert(menu.track_index==0 and menu.filter_index==0)
	owner.data.profile.quick_setup = "old malformed preference"
	menu.restore_setup()
	assert(menu.laps==2,"optional malformed setup does not invalidate profile progress")
	owner.data.profile.quick_setup = before
	assert(owner.data.reset_local(false)==OK)
	assert(owner.data.profile.quick_setup==before,"records-only reset preserves preferences")
	assert(owner.data.reset_local(true)==OK)
	menu.restore_setup()
	assert(menu.laps==2 and menu.opponents==7 and menu.contact and menu.filter_index==0)
	owner.free()
	AppData.remove_tree(ProjectSettings.globalize_path(folder))
	print("QUICK_SETUP_COLD_RESTART_DEFAULTS_TRIAL_ISOLATION_FAILED_WRITE_AND_RESET_PASS")
	quit()
