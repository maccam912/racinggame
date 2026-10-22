class_name AuthoredLandformArt
extends RefCounted
## Solid, buried-base outcrops and stepped cultivated hills for authored places.
static func emit(tool: SurfaceTool, kind: String, variant: int) -> void:
	var terraces := kind=="terraced_field"
	var basalt := kind=="basalt_crag"
	var martian := kind=="martian_butte"
	var moon := kind=="crater_outcrop"
	var width := (38.0+variant*5) if terraces else (30.0+variant*4)
	var depth := (27.0+variant*3) if terraces else (23.0+variant*3)
	var height := (32.0 if moon else 65.0 if basalt else 46.0)+variant*13
	var rings: Array[Vector2] = []
	if terraces:
		rings.assign([Vector2(1,-64),Vector2(1,-40),Vector2(.93,-40),Vector2(.93,-24),Vector2(.84,-24),Vector2(.84,-10),Vector2(.75,-10),Vector2(.75,0),Vector2(.65,0),Vector2(.65,7),Vector2(.50,7),Vector2(.50,14),Vector2(.35,14),Vector2(.35,21)])
	elif basalt:
		rings.assign([Vector2(1,-64),Vector2(1,0),Vector2(.95,height*.42),Vector2(.67,height*.75),Vector2(.38,height)])
	elif moon:
		rings.assign([Vector2(1,-64),Vector2(1,0),Vector2(.80,height*.28),Vector2(.57,height*.68),Vector2(.18,height)])
	else:
		rings.assign([Vector2(1,-64),Vector2(1,2),Vector2(.96,height*.28),Vector2(.77,height*.29),Vector2(.75,height*.62),Vector2(.64,height*.63),Vector2(.53,height)])
	var centers: Array[Vector3] = []
	for ring in range(rings.size()):
		centers.append(Vector3(sin(variant+ring*.6)*ring*.6,0,cos(variant*.7+ring*.5)*ring*.4))
	var points: Array[PackedVector3Array] = []
	for ring in range(rings.size()):
		var loop := PackedVector3Array()
		for side in range(10):
			var angle := TAU*side/10
			var shape := 1+.10*sin(side*2.3+variant)+.05*cos(side*3.7+variant*1.4)
			loop.append(centers[ring]+Vector3(cos(angle)*width*rings[ring].x*shape,rings[ring].y,sin(angle)*depth*rings[ring].x*shape))
		points.append(loop)
	for ring in range(points.size()-1):
		var level := is_equal_approx(rings[ring].y,rings[ring+1].y)
		# A shared interior point misorients the exposed lower shelves of a stepped hill.
		var inside := Vector3(0,rings[ring].y-1 if level else (rings[ring].y+rings[ring+1].y)*.5,0)
		var color: Color
		if terraces: color = Color("839D48").lerp(Color("B3BD61"),(ring%4)*.19) if level else Color("B8A46D")
		elif basalt: color = [Color("394B52"),Color("465B60"),Color("53696B"),Color("3B515B")][ring%4]
		elif moon: color = [Color("777F89"),Color("9299A2"),Color("687783"),Color("A4A8AD")][ring%4]
		elif martian: color = [Color("9C573D"),Color("C87B50"),Color("DE9B6D"),Color("AD6046")][ring%4]
		else: color = [Color("A9673F"),Color("C5834B"),Color("D7A36A"),Color("AF734B")][ring%4]
		for side in range(10):
			var next := (side+1)%10
			var shade := color.darkened(.04*(side%3))
			var a := points[ring][side]
			var b := points[ring][next]
			var c := points[ring+1][next]
			var d := points[ring+1][side]
			if terraces and not level:
				# A short planted bank makes each cultivated shelf readable from below.
				var weight := 1-minf(2.2,(d.y-a.y)*.3)/(d.y-a.y)
				var p := a.lerp(d,weight)
				var q := b.lerp(c,weight)
				ExpansionWatercraftArt.outward(tool,a,b,q,inside,shade)
				ExpansionWatercraftArt.outward(tool,a,q,p,inside,shade)
				var leaves := Color("85AE42").lightened((ring%3)*.04)
				ExpansionWatercraftArt.outward(tool,p,q,c,inside,leaves)
				ExpansionWatercraftArt.outward(tool,p,c,d,inside,leaves)
			else:
				ExpansionWatercraftArt.outward(tool,a,b,c,inside,shade)
				ExpansionWatercraftArt.outward(tool,a,c,d,inside,shade)
	for side in range(10):
		var next := (side+1)%10
		var last := points.size()-1
		ExpansionWatercraftArt.outward(tool,points[last][side],points[last][next],centers[last]+Vector3.UP*rings[last].y,Vector3(0,rings[last].y-1,0),Color("A5B85B") if terraces else Color("5C7475") if basalt else Color("A9AEB6") if moon else Color("D5A371"))
		ExpansionWatercraftArt.outward(tool,points[0][side],centers[0]+Vector3.UP*rings[0].y,points[0][next],Vector3(0,rings[0].y+1,0),Color("846846"))
