extends SceneTree

class Board extends Node2D:
	var fonts: Array[Font] = []
	func _draw() -> void:
		draw_rect(Rect2(0,0,640,480), Color("172c40"))
		for row: int in range(2):
			for column: int in range(3):
				draw_string(fonts[row], Vector2(24+column*200,80+row*180), ["👨‍👩‍👧‍👦","👍🏽","🏁"][column], HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Requires actual graphics")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var board := Board.new()
	for name: String in ["body", "heading"]:
		var font: FontVariation = load("res://assets/fonts/"+name+".tres").duplicate(true)
		font.base_font.allow_system_fallback = false
		font.fallbacks[0].allow_system_fallback = false
		board.fonts.append(font)
	viewport.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var coverage: Array[int] = []
	for row: int in range(2):
		for column: int in range(3):
			var count := 0
			for y: int in range(15+row*180,100+row*180):
				for x: int in range(24+column*200,110+column*200):
					var c := pixels.get_pixel(x,y)
					if maxf(absf(c.r-.09),maxf(absf(c.g-.173),absf(c.b-.251))) > .15: count += 1
			assert(count > 150, "Missing rendered emoji pixels with system fallback disabled")
			coverage.append(count)
	DirAccess.make_dir_recursive_absolute("res://reports/font-render")
	assert(pixels.save_png("res://reports/font-render/bundled.png") == OK)
	var report := {"passed":true,"backend":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"system_fallback":false,"pixel_coverage":coverage,"fonts":["body","heading"],"samples":["family","skin_tone","race_flag"]}
	var file := FileAccess.open("res://reports/font-render/summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("FONT_RENDER_NO_SYSTEM_FALLBACK_SIX_CELLS_PASS "+JSON.stringify(report))
	viewport.queue_free()
	await process_frame
	quit()
