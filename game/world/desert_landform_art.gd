class_name DesertLandformArt
extends RefCounted
## Narrow wind-carved sandstone blades, with an embedded closed foundation.
static func emit(t: SurfaceTool, variant: int) -> void:
	var width := 47.0+variant*6
	var depth := 15.0+posmod(variant,3)*3
	var height := 46.0+variant*12
	var rings: Array[Vector3] = [Vector3(1,1,-64),Vector3(1,1,0),Vector3(.92,.73,height*.22),Vector3(.84,.56,height*.56),Vector3(.66,.35,height*.85),Vector3(.45,.15,height)]
	var points: Array[PackedVector3Array] = []
	var centers: Array[Vector3] = []
	for r in range(rings.size()):
		var center := Vector3(r*1.4,0,sin(r*.5+variant)*r*.7)
		centers.append(center+Vector3.UP*rings[r].z)
		var loop := PackedVector3Array()
		for i in range(12):
			var angle := TAU*i/12
			var irregular := 1+.09*sin(i*2.5+variant*.8)
			loop.append(center+Vector3(cos(angle)*width*rings[r].x*irregular,rings[r].z,sin(angle)*depth*rings[r].y*irregular))
		points.append(loop)
	var palette := [Color("B88159"),Color("D3A676"),Color("E1BC8C"),Color("BC8D67"),Color("D8AC80")]
	for r in range(rings.size()-1):
		var inside := centers[r].lerp(centers[r+1],.5)
		for i in range(12):
			var j := (i+1)%12
			var ink: Color = palette[r].darkened((i%3)*.035)
			ExpansionWatercraftArt.outward(t,points[r][i],points[r][j],points[r+1][j],inside,ink)
			ExpansionWatercraftArt.outward(t,points[r][i],points[r+1][j],points[r+1][i],inside,ink)
	for i in range(12):
		var j := (i+1)%12
		ExpansionWatercraftArt.outward(t,points[0][i],centers[0],points[0][j],centers[0]+Vector3.UP,Color("A27D5B"))
		ExpansionWatercraftArt.outward(t,points[-1][i],points[-1][j],centers[-1],centers[-1]-Vector3.UP,Color("E4BF91"))
