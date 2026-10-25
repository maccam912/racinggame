extends SceneTree
## Immutable content-18 bytes stay readable/preserved under smooth beginner courses.
const SOURCE := "res://tests/fixtures/content18/"
const MANIFEST_SHA := "edec6fe6dc2141def85bb2e236390a8696df6f080a7f5c578b1f9b5e873f55af"

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	assert(Catalog.rules.content_version==22 and Catalog.rules.protocol_version==10 and SaveStore.SCHEMA==1)
	assert(FileAccess.get_sha256(SOURCE+"manifest.json")==MANIFEST_SHA,"frozen transition manifest cannot drift with new physics")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"manifest.json"))
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"compatibility.json"))
	var old_hash: String = manifest.content_hash
	assert(previous.content_hash==old_hash and old_hash!=Compatibility.content_hash())
	for name: String in ["cars","tracks","rules"]:
		assert(FileAccess.get_sha256(SOURCE+name+".json")==previous.files["game/content/"+name+".json"])
	var folder := "user://tests/content18-to19-transition-"+RaceSetup.uuid()
	DirAccess.make_dir_recursive_absolute(folder)
	var destinations: Dictionary = {}
	for name: String in manifest.files:
		var source := SOURCE+name
		assert(FileAccess.get_sha256(source)==manifest.files[name],"frozen content-18 file changed: "+name)
		var target := folder+"/"+name
		if name=="ghost.bin": target = folder+"/ghosts/palm_bay/comet/"+old_hash+".bin"
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file := FileAccess.open(target,FileAccess.WRITE)
		assert(file!=null)
		file.store_buffer(FileAccess.get_file_as_bytes(source))
		file.close()
		destinations[name] = target
	var data := AppData.new(folder,false)
	assert(data.profile.display_name=="Archive 18" and data.profile.first_run_complete)
	assert(data.records.times["trial:palm_bay:comet:"+old_hash].time==.1)
	assert(data.best("trial","palm_bay","comet")==-1 and data.load_ghost("palm_bay","comet").is_empty(),"old records/ghosts are not mixed with changed handling")
	assert(data.cup.data.content_hash==old_hash and not data.cup.compatible(Compatibility.content_hash()))
	var checkpoint := RaceCheckpoint.new(data)
	checkpoint.reload()
	assert(RaceArchive.valid(checkpoint.payload) and checkpoint.payload.content_hash==old_hash)
	assert(not checkpoint.can_resume(),"content-18 active state cannot continue under content-19 simulation")
	for name: String in destinations:
		assert(FileAccess.get_sha256(destinations[name])==manifest.files[name],"opening an incompatible component must preserve its exact bytes: "+name)
	var evidence := {"passed":true,"old_content_hash":old_hash,"new_content_hash":Compatibility.content_hash(),"old_save_schema":1,"new_save_schema":SaveStore.SCHEMA,"frozen_files_preserved":manifest.files,"old_records_preserved_but_inactive":true,"old_ghost_preserved_but_inactive":true,"old_cup_preserved_continuation_disabled":true,"old_active_race_preserved_continuation_disabled":true,"boundary":manifest.purpose}
	DirAccess.make_dir_recursive_absolute("res://reports")
	var output := FileAccess.open("res://reports/content18-to19-transition.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(evidence,"\t")+"\n")
	output.close()
	checkpoint = null
	data = null
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("FROZEN_CONTENT18_PROFILE_RECORD_GHOST_CUP_ACTIVE_RACE_BYTES_PRESERVED_CONTENT19_CONTINUATION_DISABLED_PASS")
	quit()
