class_name WorldPresentation
extends CanvasLayer
## Render the existing shared 3D world separately from the native 2D HUD.
## Keeping simulation nodes in their original viewport preserves physics/input.

var app: Node
var host: Viewport
var viewport := SubViewport.new()
var camera := Camera3D.new()
var image := TextureRect.new()
var backdrop := ColorRect.new()
var settings: Dictionary = {}
var prior_disable_3d: bool = false
var pixel_size_override := Vector2i.ZERO # Render fixture only.

func _ready() -> void:
	layer = -100
	process_priority = 100
	host = get_viewport()
	prior_disable_3d = host.disable_3d
	host.disable_3d = true
	viewport.world_3d = host.find_world_3d()
	viewport.gui_disable_input = true
	viewport.audio_listener_enable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(camera)
	camera.current = true
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.texture = viewport.get_texture()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(image)
	add_to_group("world_presentations")
	host.size_changed.connect(reflow)
	reflow()

func physical_size() -> Vector2i:
	if pixel_size_override!=Vector2i.ZERO: return pixel_size_override
	if host is Window: return (host as Window).size
	return Vector2i(host.get_visible_rect().size)

static func render_size(pixels: Vector2i, values: Dictionary) -> Vector2i:
	if values.get("retro",false): return Vector2i(640,360)
	if not OS.has_feature("mobile") and values.get("window_mode","windowed")!="windowed":
		var selected := DesktopDisplay.resolution_size(values.get("resolution","native"))
		if selected!=Vector2i.ZERO: pixels = selected
	var scale := float(values.get("render_scale",100))/100
	return Vector2i(maxi(320,roundi(pixels.x*scale)),maxi(180,roundi(pixels.y*scale)))

func apply(values: Dictionary) -> void:
	settings = values.duplicate(true)
	viewport.msaa_3d = {0:Viewport.MSAA_DISABLED,2:Viewport.MSAA_2X,4:Viewport.MSAA_4X}.get(int(values.msaa),Viewport.MSAA_DISABLED)
	viewport.anisotropic_filtering_level = {2:Viewport.ANISOTROPY_2X,4:Viewport.ANISOTROPY_4X,8:Viewport.ANISOTROPY_8X,16:Viewport.ANISOTROPY_16X}.get(int(values.anisotropic),Viewport.ANISOTROPY_4X)
	RenderingServer.directional_shadow_atlas_set_size(4096 if values.shadows=="high" else 2048,true)
	reflow()

func reflow() -> void:
	if not is_inside_tree(): return
	viewport.size = render_size(physical_size(),settings)
	# A fixed 16:9 Retro image is letterboxed on other aspect ratios. The HUD
	# retains the full host safe area and native text rendering.
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _process(_dt: float) -> void:
	var suspended: bool = is_instance_valid(app) and is_instance_valid(app.touch_editor)
	visible = not suspended
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if suspended else SubViewport.UPDATE_ALWAYS
	if suspended: return
	var source := host.get_camera_3d()
	if not is_instance_valid(source): return
	camera.global_transform = source.global_transform
	for property: String in ["projection","fov","size","near","far","keep_aspect","h_offset","v_offset","frustum_offset","cull_mask"]:
		camera.set(property,source.get(property))

func _exit_tree() -> void:
	if is_instance_valid(host): host.disable_3d = prior_disable_3d
