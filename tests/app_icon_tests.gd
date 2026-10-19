extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var root_path := "res://assets/exported/branding/"
	var foreground := Image.load_from_file(ProjectSettings.globalize_path(root_path+"adaptive-foreground.png"))
	var mono := Image.load_from_file(ProjectSettings.globalize_path(root_path+"adaptive-monochrome.png"))
	var background := Image.load_from_file(ProjectSettings.globalize_path(root_path+"adaptive-background.png"))
	var store := Image.load_from_file(ProjectSettings.globalize_path(root_path+"store-512.png"))
	assert(foreground.get_size()==Vector2i(432,432) and mono.get_size()==foreground.get_size())
	assert(background.get_size()==Vector2i(432,432) and store.get_size()==Vector2i(512,512))
	var bounds: Array[Dictionary] = []
	for image: Image in [foreground,mono]:
		var low := Vector2i(432,432)
		var high := Vector2i.ZERO
		var maximum_radius := 0.0
		var count := 0
		for y in range(432):
			for x in range(432):
				var pixel := image.get_pixel(x,y)
				if pixel.a<.004: continue
				low = low.min(Vector2i(x,y));high = high.max(Vector2i(x,y))
				var radius := Vector2(x+.5-216,y+.5-216).length()
				maximum_radius = maxf(maximum_radius,radius)
				assert(radius<=132,"Adaptive foreground must stay inside the 66 dp safe disk")
				if image==mono: assert(pixel.r>.99 and pixel.g>.99 and pixel.b>.99,"Themed icon uses white alpha artwork")
				count += 1
		var size := high-low+Vector2i.ONE
		assert(size.x>=192 and size.y>=192,"Mark must be at least 48 dp at 4x")
		assert(size.x<=264 and size.y<=264 and count>5000)
		bounds.append({"bounds":[low.x,low.y,size.x,size.y],"maximum_radius_pixels":maximum_radius,"covered_pixels":count})
	for image: Image in [background,store]:
		for y in range(image.get_height()):
			for x in range(image.get_width()): assert(image.get_pixel(x,y).a==1,"Background/store icon must be opaque")
	for size in [16,24,32,48,64,128,192,256,512,1024]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(root_path+"desktop-%d.png"%size))
		assert(image.get_size()==Vector2i(size,size))
		assert(image.get_pixel(0,0).a<.05 and image.get_pixel(size/2,size/2).a==1,"Desktop raster alpha: "+str([size,image.get_pixel(0,0),image.get_pixel(size/2,size/2)]))
	DirAccess.make_dir_recursive_absolute("res://reports/app-icons")
	var sheet := Image.create(960,352,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("f8f4e8"))
	for index in range(3):
		var tile := Image.create(288,288,false,Image.FORMAT_RGBA8)
		for y in range(288):
			for x in range(288):
				var local := Vector2(x+.5-144,y+.5-144)/144
				var inside := local.length_squared()<=1 if index!=1 else pow(absf(local.x),4)+pow(absf(local.y),4)<=1
				if not inside: continue
				var ink := mono.get_pixel(x+72,y+72) if index==2 else foreground.get_pixel(x+72,y+72)
				var base := Color("172c40") if index==2 else background.get_pixel(x+72,y+72)
				var color := Color("f3cd48") if index==2 else Color(ink,1)
				tile.set_pixel(x,y,base.lerp(color,ink.a))
		sheet.blend_rect(tile,Rect2i(0,0,288,288),Vector2i(24+index*312,32))
	assert(sheet.save_png("res://reports/app-icons/masks.png")==OK)
	var file := FileAccess.open("res://reports/app-icons/geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"adaptive_bounds":bounds,"safe_circle_dp":66,"canvas_dp":108,"layer_pixels":432,"opaque_store":true,"desktop_sizes":[16,24,32,48,64,128,192,256,512,1024]},"  "))
	file.close()
	print("APP_ICON_ADAPTIVE_SAFE_DISK_MINIMUM_SIZE_MONO_ALPHA_OPAQUE_STORE_DESKTOP_SIZES_PASS "+JSON.stringify(bounds))
	quit()
