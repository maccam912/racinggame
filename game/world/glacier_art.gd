class_name GlacierArt
extends RefCounted
## Wide blue glacier faces and squat snow-capped erratics, with buried closed bases.
static func emit(t: SurfaceTool, kind: String, variant: int) -> void:
	var headwall := kind=="frozen_headwall"
	var wall := kind=="ice_wall" or headwall
	assert(wall or kind=="glacial_erratic")
	var outline := PackedVector2Array([Vector2(-1,-.65),Vector2(-.62,-.93),Vector2(-.18,-.82),Vector2(.24,-1),Vector2(.68,-.84),Vector2(1,-.58),Vector2(.93,.67),Vector2(.34,.87),Vector2(-.31,.73),Vector2(-.94,.88)])
	var width := (60.0+variant*6) if wall else (21.0+variant*3)
	var depth := (24.0+variant*3) if wall else (17.0+variant*2)
	var height := (32.0+variant*9) if wall else (13.0+variant*4)
	if headwall:
		width = 48
		depth = 30
		height = 68
	var rings: Array[PackedVector3Array] = []
	for level in range(4):
		var ring := PackedVector3Array()
		for corner in range(outline.size()):
			var crest := height*(.82+.12*sin(corner*1.7+variant*.9)+.06*cos(corner*2.3))
			var y := -64.0 if level==0 else crest*.42 if level==1 else crest-3.5 if level==2 else crest
			var shrink := [1.0,.98,.86,.81][level] as float
			var point := outline[corner]*shrink
			ring.append(Vector3(point.x*width+(0 if level==0 else sin(variant)*level*1.1),y,point.y*depth))
		rings.append(ring)
	for level in range(3):
		var color: Color
		if wall: color = [Color("578B9F"),Color("83B7CB"),Color("D9E7E6")][level]
		else: color = [Color("647784"),Color("85949B"),Color("D7E1DD")][level]
		for corner in range(outline.size()):
			var next := (corner+1)%outline.size()
			var a := rings[level][corner]
			var b := rings[level][next]
			var c := rings[level+1][next]
			var d := rings[level+1][corner]
			var inside := Vector3(0,(a.y+b.y+c.y+d.y)*.25,0)
			var shade := color.darkened((corner%3)*.055)
			ExpansionWatercraftArt.outward(t,a,b,c,inside,shade)
			ExpansionWatercraftArt.outward(t,a,c,d,inside,shade)
	var center := Vector3.ZERO
	for p: Vector3 in rings[3]: center += p/rings[3].size()
	for corner in range(outline.size()):
		var next := (corner+1)%outline.size()
		ExpansionWatercraftArt.outward(t,rings[3][corner],rings[3][next],center,Vector3(0,0,0),Color("E2ECE9"))
		ExpansionWatercraftArt.outward(t,rings[0][corner],Vector3(0,-64,0),rings[0][next],Vector3(0,-63,0),Color("657C89"))

static func frozen_falls(solid: SurfaceTool, ice: SurfaceTool) -> void:
	emit(solid,"frozen_headwall",0)
	# Uneven sheets run over the natural lip and fan out at the frozen basin.
	# They are static ice, without the sluice's rectangular pylons and lintel.
	for band in range(9):
		var x := -23.0+band*5.75
		var top := 41.0+(band%3)*2
		var rows: Array[Vector3] = [Vector3(x,top,18),Vector3(x,top*.70,26),Vector3(x*1.06,top*.32,30),Vector3(x*1.15,-3,35)]
		var color := Color("A8DDED").lightened((band%3)*.035)
		for row in range(rows.size()-1):
			var a := rows[row]+Vector3(-2.7,0,0)
			var b := rows[row]+Vector3(2.7,0,.5)
			var c := rows[row+1]+Vector3(2.9,0,.5)
			var d := rows[row+1]+Vector3(-2.9,0,0)
			ExpansionWatercraftArt.outward(ice,a,b,c,Vector3(0,20,0),color)
			ExpansionWatercraftArt.outward(ice,a,c,d,Vector3(0,20,0),color.lightened(.035))
		CourseDecor.stone(ice,Vector3(x*1.2,-4,35),Vector3(5.5,6+(band%3)*2,5),Color("AFD9E4"),band+2)
