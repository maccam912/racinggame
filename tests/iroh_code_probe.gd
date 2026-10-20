extends SceneTree
## Exercise the shipped discovery client for an explicitly supplied fixture code.

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var code := ""
	var report := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--code="): code = argument.trim_prefix("--code=")
		elif argument.begins_with("--report="): report = argument.trim_prefix("--report=")
	assert(IrohRendezvous.valid_code(code))
	var service := IrohRendezvous.new()
	root.add_child(service)
	var result := await service.resolve(code)
	var value := {"resolved":bool(result.ok),"expired":not result.ok and result.get("message")==I18n.t("online.iroh_expired")}
	if not report.is_empty():
		var file := FileAccess.open(report,FileAccess.WRITE)
		assert(file!=null)
		file.store_string(JSON.stringify(value))
		file.close()
	service.queue_free()
	await process_frame
	print("IROH_CODE_PROBE "+JSON.stringify(value))
	quit()
