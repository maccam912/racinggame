class_name TouchLayoutBook
extends RefCounted
## Centers are normalized within the OS-safe logical rectangle. Control variants
## keep manual/automatic, slider/buttons and handedness from invalidating each other.

const ACTIONS := ["steer","left","right","throttle","brake","boost","handbrake","recover","camera","look_back","pause"]

static func profile_key(safe: Rect2,automatic: bool,steering: String,mirrored: bool) -> String:
	return "%s_%s_%s_%s_%s" % ["landscape" if safe.size.x>=safe.size.y else "portrait","tablet" if minf(safe.size.x,safe.size.y)>=600 else "phone","auto" if automatic else "manual",steering,"left" if mirrored else "right"]

static func valid_center(value: Variant) -> bool:
	if not value is Array or value.size()!=2:
		return false
	for coordinate: Variant in value:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or float(coordinate)<0 or float(coordinate)>1:
			return false
	return true

static func centers(layout: Dictionary,safe: Rect2) -> Dictionary:
	var result: Dictionary = {}
	for action: String in layout:
		var center: Vector2 = (layout[action].get_center()-safe.position)/safe.size
		result[action] = [center.x,center.y]
	return result

static func resolve(base: Dictionary,safe: Rect2,saved: Variant) -> Dictionary:
	if base.is_empty():
		return {"controls":{},"reset":false}
	if saved==null or saved is Dictionary and saved.is_empty():
		return {"controls":base.duplicate(),"reset":false}
	if not saved is Dictionary:
		return {"controls":base.duplicate(),"reset":true}
	var result := base.duplicate()
	for action: String in base:
		if not saved.has(action):
			continue
		if not valid_center(saved[action]):
			return {"controls":base.duplicate(),"reset":true}
		var fraction := Vector2(float(saved[action][0]),float(saved[action][1]))
		var dimensions: Vector2 = base[action].size
		var center := TouchDriving.clamp_center(safe,safe.position+safe.size*fraction,dimensions,action)
		result[action] = Rect2(center-dimensions/2,dimensions)
	if not TouchDriving.legal_layout(result,safe):
		return {"controls":base.duplicate(),"reset":true}
	return {"controls":result,"reset":false}

static func with_profile(saved: Dictionary,key: String,layout: Dictionary,safe: Rect2) -> Dictionary:
	var updated := saved.duplicate(true)
	updated[key] = centers(layout,safe)
	return updated


static func snapped_center(safe: Rect2,center: Vector2,dimensions: Vector2,action: String) -> Vector2:
	var low := TouchDriving.clamp_center(safe,safe.position-Vector2.ONE*100000,dimensions,action)
	var high := TouchDriving.clamp_center(safe,safe.end+Vector2.ONE*100000,dimensions,action)
	low = safe.position+((low-safe.position)/8).ceil()*8
	high = safe.position+((high-safe.position)/8).floor()*8
	return (safe.position+(center-safe.position).snapped(Vector2.ONE*8)).clamp(low,high)
