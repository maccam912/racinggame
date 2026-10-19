class_name UnicodeGraphemes
extends RefCounted
## Unicode 16 extended clusters, independent of the installed TextServer.
enum GCB { OTHER, CR, LF, CONTROL, EXTEND, ZWJ, RI, PREPEND, SPACING, L, V, T, LV, LVT }
static var tables: Dictionary = {}

static func prepare() -> void:
	if not tables.is_empty(): return
	tables = JSON.parse_string(FileAccess.get_file_as_string("res://game/content/unicode_graphemes.json"))
	assert(tables.get("unicode_version")=="16.0.0")

static func property(point: int, rows: Array) -> int:
	var low := 0
	var high := rows.size()-1
	while low<=high:
		var middle := (low+high)/2
		var row: Array = rows[middle]
		if point<int(row[0]): high = middle-1
		elif point>int(row[1]): low = middle+1
		else: return int(row[2])
	return 0

static func count(value: String) -> int:
	var points: Array[int] = []
	for index in range(value.length()): points.append(value.unicode_at(index))
	return boundaries(points).size()-1

static func boundaries(points: Array[int]) -> Array[int]:
	prepare()
	var result: Array[int] = [0]
	if points.is_empty(): return result
	var classes: Array[int] = []
	var pictographic: Array[bool] = []
	var conjunct: Array[int] = []
	for point: int in points:
		# GB6–8 Hangul syllables have an exact algorithmic LV/LVT split.
		classes.append((GCB.LV if (point-0xac00)%28==0 else GCB.LVT) if point>=0xac00 and point<=0xd7a3 else property(point,tables.gcb))
		pictographic.append(property(point,tables.pictographic)==1)
		conjunct.append(property(point,tables.incb))
	for index in range(1,points.size()):
		var previous := classes[index-1]
		var current := classes[index]
		var joined := false
		if previous==GCB.CR and current==GCB.LF: joined = true # GB3
		elif previous in [GCB.CR,GCB.LF,GCB.CONTROL] or current in [GCB.CR,GCB.LF,GCB.CONTROL]: pass # GB4/5
		elif previous==GCB.L and current in [GCB.L,GCB.V,GCB.LV,GCB.LVT]: joined = true # GB6
		elif previous in [GCB.LV,GCB.V] and current in [GCB.V,GCB.T]: joined = true # GB7
		elif previous in [GCB.LVT,GCB.T] and current==GCB.T: joined = true # GB8
		elif current in [GCB.EXTEND,GCB.ZWJ,GCB.SPACING] or previous==GCB.PREPEND: joined = true # GB9/9a/9b
		else:
			if conjunct[index]==1: # GB9c: consonant + marks containing a linker.
				var at := index-1
				var linker := false
				while at>=0 and conjunct[at] in [2,3]:
					if conjunct[at]==2: linker = true
					at -= 1
				joined = linker and at>=0 and conjunct[at]==1
			if not joined and pictographic[index] and previous==GCB.ZWJ: # GB11
				var at := index-2
				while at>=0 and classes[at]==GCB.EXTEND: at -= 1
				joined = at>=0 and pictographic[at]
			if not joined and previous==GCB.RI and current==GCB.RI: # GB12/13
				var at := index-1
				while at>=0 and classes[at]==GCB.RI: at -= 1
				joined = (index-1-at)%2==1
		if not joined: result.append(index) # GB999
	result.append(points.size())
	return result
