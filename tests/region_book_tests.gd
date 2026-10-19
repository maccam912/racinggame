extends SceneTree

func _initialize() -> void: call_deferred("run_tests")

func run_tests() -> void:
	Catalog.load_all()
	var book := RegionBook.new()
	root.add_child(book)
	assert(book.configure(PackedStringArray())==OK and book.regions.size()==2)
	assert(book.selected().is_empty())
	book.probe()
	await book.updated
	assert(not book.probing and book.requests.is_empty() and book.selected().is_empty())
	assert(book.configure(PackedStringArray(["--directory-url=https://LOCALHOST:29443/"]))==OK)
	assert(book.regions.size()==1 and book.regions[0].id=="test" and book.regions[0].url=="https://localhost:29443")
	book.regions.assign([
		{"id":"us-central","name_key":"online.us","url":"https://central.invalid","available":false,"ping_ms":60000.0,"samples":[100.0,20.0],"finished":false},
		{"id":"europe-west","name_key":"online.eu","url":"https://west.invalid","available":false,"ping_ms":60000.0,"samples":[15.0,15.0],"finished":false}])
	book.probing = true
	var active := book.generation
	book.record_probe(0,10.0,active)
	assert(book.regions[0].available and book.regions[0].ping_ms==20.0)
	book.record_probe(1,60000.0,active)
	assert(not book.probing and book.regions[1].available and book.selected().id=="europe-west")
	book.selected_id = "us-central"
	assert(book.selected().id=="us-central")
	book.regions[0].available = false
	assert(book.selected().is_empty())
	book.selected_id = "auto"
	book.regions[1].available = false
	assert(book.selected().is_empty())
	book.cancel()
	book.record_probe(0,1.0,active)
	assert(not book.regions[0].available,"stale probes cannot revive cancelled results")
	assert(book.configure(PackedStringArray(["--directory-url=http://localhost"]))==ERR_INVALID_PARAMETER)
	book.queue_free()
	await process_frame
	print("REGION_BOOK_MEDIAN_AUTO_UNAVAILABLE_CANCEL_PASS")
	quit()
