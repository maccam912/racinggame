class_name RoutePreview
extends Control
## Canonical map, distance grid, direction arrows and a true lap elevation profile.
var unit: float = 1.0
var frame := StyleBoxFlat.new()
var track: TrackDefinition:
	set(value):
		track = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	frame.bg_color = Color("102337")
	frame.border_color = Color("416073")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(6)
	resized.connect(queue_redraw)

func _draw() -> void:
	if track==null or size.x<80 or size.y<80: return
	var u := unit
	var font: Font = load("res://assets/fonts/body.tres")
	var fs := roundi(12*u)
	var box := Rect2(Vector2.ZERO,size)
	draw_style_box(frame,box)
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	var low := INF
	var high := -INF
	for point: Vector3 in track.points:
		lo = lo.min(Vector2(point.x,point.z))
		hi = hi.max(Vector2(point.x,point.z))
		low = minf(low,point.y)
		high = maxf(high,point.y)
	var area := Rect2(Vector2(26,26)*u,Vector2(size.x-52*u,size.y-88*u))
	var zoom := minf(area.size.x/maxf(hi.x-lo.x,1),area.size.y/maxf(hi.y-lo.y,1))
	var offset := area.position+(area.size-(hi-lo)*zoom)/2
	var step := 1000.0 if zoom*500<28*u else 500.0 if zoom*250<28*u else 250.0
	for x in range(int(floor(lo.x/step)),int(ceil(hi.x/step))+1):
		var px := offset.x+(x*step-lo.x)*zoom
		draw_line(Vector2(px,area.position.y),Vector2(px,area.end.y),Color("203c50"),u)
	for z in range(int(floor(lo.y/step)),int(ceil(hi.y/step))+1):
		var py := offset.y+(z*step-lo.y)*zoom
		draw_line(Vector2(area.position.x,py),Vector2(area.end.x,py),Color("203c50"),u)
	var route := PackedVector2Array()
	# Retain every bake sample; small-radius turns must not become angular chords.
	for point: Vector3 in track.points: route.append(offset+(Vector2(point.x,point.z)-lo)*zoom)
	route.append(route[0])
	var shadow := PackedVector2Array()
	for point: Vector2 in route: shadow.append(point+Vector2(1.5,2.5)*u)
	draw_polyline(shadow,Color("060f1c"),10*u,true)
	draw_polyline(route,Color("638391"),8*u,true)
	draw_polyline(route,Color("eff2db"),4*u,true)
	for fraction: float in [.16,.39,.63,.84]:
		var i := track.sample_index(track.length*fraction)
		var tangent := (route[(i+8)%track.points.size()]-route[i]).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		var p := route[i]
		draw_polyline(PackedVector2Array([p-tangent*6*u+normal*4*u,p,p-tangent*6*u-normal*4*u]),UIFactory.TURQUOISE,2*u,true)
	var start := route[0]
	draw_circle(start,7*u,Color("102337"))
	for x in range(2):
		for y in range(2):
			draw_rect(Rect2(start+Vector2(x*4-4,y*4-4)*u,Vector2(4,4)*u),UIFactory.CREAM if (x+y)%2==0 else UIFactory.NAVY)
	draw_string(font,Vector2(10,17)*u,I18n.t("course.circuit"),HORIZONTAL_ALIGNMENT_LEFT,-1,fs,UIFactory.CREAM)
	draw_string(font,Vector2(size.x-24*u,17*u),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,UIFactory.TURQUOISE)
	var baseline := size.y-13*u
	var profile := PackedVector2Array()
	for i in range(0,track.points.size(),maxi(1,track.points.size()/160)):
		profile.append(Vector2(12*u+track.distances[i]/track.length*(size.x-24*u),baseline-(track.points[i].y-low)/maxf(high-low,1)*20*u))
	profile.append(Vector2(size.x-12*u,baseline-(track.points[0].y-low)/maxf(high-low,1)*20*u))
	draw_line(Vector2(12*u,baseline),Vector2(size.x-12*u,baseline),Color("416073"),u)
	draw_polyline(profile,UIFactory.TURQUOISE,1.5*u,true)
	draw_string(font,Vector2(12*u,size.y-41*u),I18n.t("course.elevation",[roundi(high-low)]),HORIZONTAL_ALIGNMENT_LEFT,-1,fs,UIFactory.CREAM)
	var bar := step*zoom
	if bar<size.x*.4:
		var p := Vector2(size.x-12*u-bar,size.y-46*u)
		draw_line(p,p+Vector2(bar,0),UIFactory.CREAM,u)
		draw_line(p-Vector2(0,3)*u,p+Vector2(0,3)*u,UIFactory.CREAM,u)
		draw_line(p+Vector2(bar,-3*u),p+Vector2(bar,3*u),UIFactory.CREAM,u)
		draw_string(font,p-Vector2(0,5)*u,str(int(step))+" m",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(10*u),Color("9db2bd"))
