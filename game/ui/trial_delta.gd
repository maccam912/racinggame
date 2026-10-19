class_name TrialDelta
extends RefCounted
## Presentation-only time comparison at equal route progress in a matching ghost.
## The 20 Hz transform stream remains the persisted PRGH v1 contract.

var progress := PackedFloat32Array()
var times := PackedFloat32Array()
var total_time: float = -1
var length: float = 0

func build(track: TrackDefinition, ghost: Dictionary) -> void:
	progress.clear()
	times.clear()
	if ghost.is_empty(): return
	length = track.length
	total_time = float(ghost.time)
	var hint := track.sample_index(-8)
	var prior_s := length-8
	var unwrapped := -8.0
	for sample: Dictionary in ghost.samples:
		var best := INF
		var route_s := prior_s
		var next_hint := hint
		for offset in range(-8,9):
			var index := posmod(hint+offset,track.points.size())
			var a := track.points[index]
			var segment := track.points[(index+1)%track.points.size()]-a
			var fraction := clampf((sample.position-a).dot(segment)/segment.length_squared(),0,1)
			var distance: float = sample.position.distance_squared_to(a+segment*fraction)
			if distance<best:
				best = distance
				route_s = track.distances[index]+segment.length()*fraction
				next_hint = index
		var movement := fposmod(route_s-prior_s+length/2,length)-length/2
		if best>144 or absf(movement)>12:
			progress.clear()
			times.clear()
			return # Damaged/unrepresentative transforms do not invent a comparison.
		unwrapped += movement
		prior_s = route_s
		hint = next_hint
		if progress.is_empty() or unwrapped>progress[-1]+.001:
			progress.append(unwrapped)
			times.append(float(sample.time))
	if progress.size()<2: return
	# The final PRGH sample is the exact sub-tick crossing, including quantization.
	progress[-1] = length
	times[-1] = total_time

func delta(state: VehicleState, elapsed: float) -> Variant:
	if progress.size()<2 or not state.trial_valid or state.dnf_reason!="": return null
	if state.finished: return state.finish_time-total_time
	var at := state.route_s
	if at<0: at = progress[0]
	elif state.last_gate<0 and at>length/2: at -= length
	if at<progress[0] or at>length: return null
	var low := 0
	var high := progress.size()-1
	while high-low>1:
		var middle := (high+low)/2
		if progress[middle]<=at: low = middle
		else: high = middle
	var fraction := inverse_lerp(progress[low],progress[high],at)
	return elapsed-lerpf(times[low],times[high],clampf(fraction,0,1))
