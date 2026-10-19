extends SceneTree
## Original editable coupe/sunrise vectors and platform raster/container exports.
## Run with the pinned engine, then iconutil on macOS for the .icns container.
const OUT := "res://assets/exported/branding/"
const BODY := '<path d="M40 130a88 88 0 0 1 176 0" fill="none" stroke="#F8F4E8" stroke-width="%s"/><path d="m35 156 21-40 29-23h84l30 23 22 40v40H35z" fill="#F16B50" stroke="#172C40" stroke-width="8"/><path d="m80 106-17 28h131l-20-28z" fill="#172C40"/><path d="M115 142h26v49h-26z" fill="#F8F4E8"/><path d="M48 156h42v16H48zm118 0h42v16h-42z" fill="#F8F4E8"/>'
const MONO := '<path d="M40 130a88 88 0 0 1 176 0" fill="none" stroke="white" stroke-width="20"/><path fill="white" fill-rule="evenodd" d="M31 156 53 113 84 89H171L202 113 225 156V200H31ZM80 106 63 134H194L174 106ZM115 142H141V191H115ZM48 156H90V172H48ZM166 156H208V172H166Z"/>'
var rows: Array[Dictionary] = []
var rasters: Dictionary = {}
func _initialize() -> void: call_deferred("run")

func svg(size: int, body: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 256 256"><title>Pacific Rush coral coupe and sunrise</title>%s</svg>\n'%[size,size,body]

func vector(path: String, source: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(source)
	file.close()

func record(path: String, kind: String, size: int = 0) -> void:
	var row := {"path":path.trim_prefix("res://"),"kind":kind,"sha256":FileAccess.get_sha256(path)}
	if size>0: row.merge({"width":size,"height":size})
	rows.append(row)

func raster(name: String, source: String, size: int) -> Image:
	var image := Image.new()
	assert(image.load_svg_from_string(source)==OK)
	assert(image.get_size()==Vector2i(size,size))
	assert(image.save_png(OUT+name)==OK)
	record(OUT+name,"png",size)
	return image

func run() -> void:
	assert(DirAccess.make_dir_recursive_absolute(OUT)==OK)
	var full := '<rect width="256" height="256" rx="48" fill="#20BFC5"/>'+BODY%"18"
	vector("res://assets/exported/icon.svg",svg(1024,full))
	record("res://assets/exported/icon.svg","canonical_vector",1024)
	for size in [16,24,32,48,64,128,192,256,512,1024]:
		rasters[size] = raster("desktop-%d.png"%size,svg(size,full),size)
	var store := '<rect width="256" height="256" fill="#20BFC5"/>'+BODY%"18"
	vector(OUT+"store.svg",svg(512,store))
	record(OUT+"store.svg","store_vector",512)
	raster("store-512.png",svg(512,store),512)
	# Recenter the enclosing circle, with a 48+ dp mark inside the 66 dp safe disk.
	# Layers are 108 dp at 4x (432 pixels). No baked mask or outer shadow.
	var transform := '<g transform="translate(128 128) scale(.682) translate(-128 -141)">%s</g>'
	var layers := {"background":'<rect width="256" height="256" fill="#20BFC5"/>',"foreground":transform%(BODY%"20"),"monochrome":transform%MONO}
	for name: String in layers:
		var source := svg(432,layers[name])
		vector(OUT+"adaptive-"+name+".svg",source)
		record(OUT+"adaptive-"+name+".svg","adaptive_vector",432)
		raster("adaptive-"+name+".png",source,432)
	var ico := FileAccess.open(OUT+"app.ico",FileAccess.WRITE)
	assert(ico!=null)
	var sizes := [16,24,32,48,64,128,256]
	ico.store_16(0);ico.store_16(1);ico.store_16(sizes.size())
	var offset: int = 6+16*sizes.size()
	var buffers: Array[PackedByteArray] = []
	for size: int in sizes:
		var image: Image = rasters[size]
		var bytes := image.save_png_to_buffer()
		buffers.append(bytes)
		ico.store_8(0 if size==256 else size);ico.store_8(0 if size==256 else size)
		ico.store_8(0);ico.store_8(0);ico.store_16(1);ico.store_16(32)
		ico.store_32(bytes.size());ico.store_32(offset)
		offset += bytes.size()
	for bytes: PackedByteArray in buffers: ico.store_buffer(bytes)
	ico.close()
	record(OUT+"app.ico","windows_icon")
	var iconset := OUT+"app.iconset/"
	assert(DirAccess.make_dir_recursive_absolute(iconset)==OK)
	for size in [16,32,128,256,512]:
		for retina in [false,true]:
			var pixels: int = size*2 if retina else size
			var name := "icon_%dx%d%s.png"%[size,size,"@2x" if retina else ""]
			var image: Image = rasters[pixels]
			assert(image.save_png(iconset+name)==OK)
			record(iconset+name,"macos_iconset",pixels)
	var manifest := {"schema_version":1,"creator":"Pacific Rush contributors","license":"MIT","source":"assets/source/generate_app_icons.gd","source_sha256":FileAccess.get_sha256("res://assets/source/generate_app_icons.gd"),"palette":["20BFC5","F16B50","F8F4E8","172C40"],"adaptive_layer_pixels":432,"adaptive_canvas_dp":108,"safe_circle_dp":66,"files":rows}
	var file := FileAccess.open(OUT+"catalog.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  "))
	file.close()
	print("ORIGINAL_APP_ICON_VECTORS_RASTERS_WINDOWS_AND_MAC_ICONSET_PASS files="+str(rows.size()))
	quit()
