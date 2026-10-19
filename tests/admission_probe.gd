extends SceneTree
## Source-only adversarial client. No deployment keys or identity secrets.
var link := NetworkClient.new()
var message: String = ""
var accepted: bool = false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var port := 27060
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
	link.admission_ticket = OS.get_environment("PR_TEST_TICKET")
	link.disconnected_permanently.connect(func(value: String) -> void: message = value)
	link.lobby_changed.connect(func(_value: Dictionary) -> void: accepted = true)
	root.add_child(link)
	link.connect_to("127.0.0.1", port, "Probe Driver")
	var deadline := Time.get_ticks_msec() + 5000
	while message == "" and not accepted and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := message != "" and not accepted and not link.connected
	print("ADMISSION_PROBE rejected=%s" % passed)
	link.queue_free()
	await process_frame
	quit(0 if passed else 1)
