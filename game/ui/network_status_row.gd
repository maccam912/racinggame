class_name NetworkStatusRow
extends VBoxContainer
var network: NetworkClient
var button: Button
var detail: Label
var next_update: int = 0

func _init(ui: UIFactory, client: NetworkClient) -> void:
	network = client
	button = ui.button(I18n.t("pause.network"),func() -> void: button.grab_focus())
	button.name = "network_status"
	add_child(button)
	detail = ui.paragraph("")
	detail.hide()
	add_child(detail)
	button.focus_entered.connect(refresh)
	button.focus_exited.connect(func() -> void: detail.hide())

func refresh() -> void:
	if not is_instance_valid(network) or not button.has_focus():
		detail.hide()
		return
	var values := network.quality.measure(Time.get_ticks_msec(),network.start_tick>=0 and network.phase!=RaceSession.Phase.RESULTS)
	var latency := str(roundi(values.rtt_ms))+" ms" if values.rtt_available else I18n.t("network.measuring")
	detail.text = I18n.t("network.detail",[latency,"%.1f"%values.loss_percent])
	detail.show()
	next_update = Time.get_ticks_msec()+500

func _process(_dt: float) -> void:
	if button.has_focus() and Time.get_ticks_msec()>=next_update: refresh()
