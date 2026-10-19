class_name SettingsRuntime
extends RefCounted


static func apply(owner_node: Node, settings: Dictionary, display: bool = false) -> void:
	Engine.max_fps = int(settings.frame_cap)
	if display: DesktopDisplay.apply(settings)
	var viewport := owner_node.get_viewport()
	var presented := false
	for presentation: WorldPresentation in owner_node.get_tree().get_nodes_in_group("world_presentations"):
		if presentation.host==viewport:
			presentation.apply(settings)
			presented = true
	if not presented:
		viewport.msaa_3d = {0:Viewport.MSAA_DISABLED, 2:Viewport.MSAA_2X, 4:Viewport.MSAA_4X}.get(int(settings.msaa), Viewport.MSAA_DISABLED)
		viewport.scaling_3d_scale = float(settings.render_scale) / 100
	var mixed := false
	for mixer: AudioMix in owner_node.get_tree().get_nodes_in_group("audio_mixes"):
		mixer.configure(settings)
		mixed = true
	if not mixed:
		var master := float(settings.master)/100
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(master,.0001)))
		AudioServer.set_bus_mute(0,master<=0)
	for item: Node in owner_node.get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = item.environment
		environment.adjustment_enabled = true
		environment.adjustment_brightness = float(settings.brightness)
	for item: Node in owner_node.get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		item.shadow_enabled = settings.shadows != "off"
		item.directional_shadow_max_distance = 160.0 if settings.shadows=="high" else 80.0
	for item: GeometryInstance3D in owner_node.get_tree().get_nodes_in_group("scenery_distance"):
		item.visibility_range_end = float(settings.draw_distance)
	if DisplayServer.get_name() != "headless" and not OS.has_feature("mobile"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
