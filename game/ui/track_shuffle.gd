class_name TrackShuffle
extends RefCounted
## Session-local shuffled tours, independent for each distinct visible roster.
var rng := RandomNumberGenerator.new()
var remaining: Dictionary = {}

func _init(seed_value: int = -1) -> void:
	if seed_value<0: rng.randomize()
	else: rng.seed = seed_value

func normalized(eligible: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for index: int in eligible:
		if not index in result: result.append(index)
	result.sort()
	return result

func shuffled(eligible: Array[int]) -> Array[int]:
	var result := eligible.duplicate()
	for i in range(result.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var value: int = result[i]
		result[i] = result[j]
		result[j] = value
	return result

func note_visit(eligible: Array[int], current: int) -> void:
	var key := str(normalized(eligible))
	if remaining.has(key): remaining[key].erase(current)

func choose(eligible: Array[int], current: int) -> int:
	var roster := normalized(eligible)
	if roster.is_empty(): return -1
	if roster.size()==1: return roster[0]
	var key := str(roster)
	var first_use := not remaining.has(key)
	var bag: Array[int] = []
	if first_use:
		bag = shuffled(roster)
		bag.erase(current)
	else:
		bag.assign(remaining[key])
		# Manual browsing or selection in another filter counts as a visit.
		bag.erase(current)
		if bag.is_empty(): bag = shuffled(roster)
	# Keep every member in a fresh cycle while avoiding a boundary repeat.
	if bag[-1]==current:
		assert(bag.size()>1)
		var j := rng.randi_range(0,bag.size()-2)
		bag[-1] = bag[j]
		bag[j] = current
	var selected: int = bag.pop_back()
	remaining[key] = bag
	return selected
