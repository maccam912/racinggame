class_name RegionBook
extends Node
## Three verified regional probes; Auto uses the lower median successful region.
signal updated
var regions: Array[Dictionary] = []
var selected_id: String = "auto"
var certificate: X509Certificate
var generation: int = 0
var requests: Array[HTTPRequest] = []
var probing: bool = false
var last_probe_ms: int = -30000
var probe_timeout: float = 2.0

func configure(arguments: PackedStringArray) -> Error:
	cancel()
	regions.clear()
	var path := ""
	var test_url := ""
	for arg: String in arguments:
		if arg.begins_with("--directory-url="): test_url = arg.trim_prefix("--directory-url=")
		if arg.begins_with("--directory-ca="): path = arg.trim_prefix("--directory-ca=")
	certificate = null
	if not path.is_empty():
		certificate = X509Certificate.new()
		if certificate.load(path)!=OK:
			certificate = null
			return ERR_FILE_CORRUPT
	if not test_url.is_empty():
		var canonical := DirectorySchema.base_url(test_url)
		if canonical.is_empty():
			return ERR_INVALID_PARAMETER
		regions.append({"id":"test","name_key":"online.test","url":canonical})
	else:
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://game/content/regions.json"))!=OK or not parser.data is Dictionary or parser.data.get("schema_version")!=1 or not parser.data.get("regions") is Array:
			return ERR_FILE_CORRUPT
		for row: Variant in parser.data.regions:
			if not row is Dictionary or not DirectorySchema.region_id(row.get("id")) or not row.get("name_key") is String or not row.get("url") is String or not row.url.is_empty() and DirectorySchema.base_url(row.url).is_empty():
				return ERR_FILE_CORRUPT
			var region: Dictionary = row.duplicate(true)
			region.url = "" if row.url.is_empty() else DirectorySchema.base_url(row.url)
			regions.append(region)
	for row: Dictionary in regions:
		row.available = false
		row.ping_ms = 60000.0
		row.samples = []
		row.finished = row.url.is_empty()
	return OK

func selected() -> Dictionary:
	if selected_id!="auto":
		for row: Dictionary in regions:
			if row.id==selected_id and row.available:
				return row
		return {}
	var best: Dictionary = {}
	for row: Dictionary in regions:
		if row.available and (best.is_empty() or float(row.ping_ms)<float(best.ping_ms) or is_equal_approx(float(row.ping_ms),float(best.ping_ms)) and str(row.id)<str(best.id)):
			best = row
	return best

func probe() -> void:
	cancel()
	probing = true
	last_probe_ms = Time.get_ticks_msec()
	for index in range(regions.size()):
		regions[index].available = false
		regions[index].ping_ms = 60000.0
		regions[index].samples = []
		regions[index].finished = str(regions[index].url).is_empty()
		if not regions[index].finished:
			next_probe(index,generation)
	finish_if_ready.call_deferred()

func next_probe(index: int, active: int) -> void:
	if active!=generation or not probing:
		return
	var row: Dictionary = regions[index]
	var current := HTTPRequest.new()
	current.use_threads = true
	current.timeout = probe_timeout
	current.max_redirects = 0
	current.body_size_limit = 32768
	current.download_chunk_size = 4096
	if certificate!=null:
		current.set_tls_options(TLSOptions.client(certificate))
	add_child(current)
	requests.append(current)
	var start := Time.get_ticks_usec()
	current.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
		requests.erase(current)
		current.queue_free()
		if active!=generation or not probing:
			return
		var valid := false
		if result==HTTPRequest.RESULT_SUCCESS and status==200:
			var parser := JSON.new()
			if parser.parse(bytes.get_string_from_utf8())==OK and parser.data is Dictionary and DirectorySchema.regions(parser.data):
				for candidate: Dictionary in parser.data.regions:
					if candidate.id==row.id and candidate.available and DirectorySchema.base_url(candidate.url)==row.url:
						valid = true
		record_probe(index,float(Time.get_ticks_usec()-start)/1000 if valid else 60000.0,active))
	if current.request(str(row.url)+"/v1/regions")!=OK:
		requests.erase(current)
		current.queue_free()
		record_probe(index,60000.0,active)

func record_probe(index: int, milliseconds: float, active: int) -> void:
	if active!=generation or not probing:
		return
	var row: Dictionary = regions[index]
	row.samples.append(milliseconds)
	if row.samples.size()<3:
		next_probe(index,active)
		return
	var samples: Array = row.samples.duplicate()
	samples.sort()
	row.ping_ms = float(samples[1])
	row.available = row.ping_ms<60000.0
	row.finished = true
	finish_if_ready()

func finish_if_ready() -> void:
	if not probing:
		return
	for row: Dictionary in regions:
		if not row.finished:
			return
	probing = false
	updated.emit()

func cancel() -> void:
	generation += 1
	probing = false
	for current: HTTPRequest in requests:
		if is_instance_valid(current):
			current.cancel_request()
			current.queue_free()
	requests.clear()

func _exit_tree() -> void:
	cancel()
