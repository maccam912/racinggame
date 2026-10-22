extends SceneTree
func _initialize() -> void:
	var helper := load("res://game/ui/track_shuffle.gd")
	var picks := 0
	for size in [2,5,10,30,40]:
		var roster: Array[int] = []
		for index in range(size): roster.append(index)
		for seed_value in range(20):
			var chooser = helper.new(seed_value)
			var current := 0
			var seen: Array[int] = [current]
			for pick in range(size-1):
				var selected: int = chooser.choose(roster,current)
				assert(selected in roster and selected!=current and not selected in seen)
				seen.append(selected)
				current = selected
				picks += 1
			for cycle in range(3):
				seen.clear()
				for pick in range(size):
					var selected: int = chooser.choose(roster,current)
					assert(selected in roster and selected!=current and not selected in seen)
					seen.append(selected)
					current = selected
					picks += 1
	var a: Array[int] = [1,2,3,4]
	var b: Array[int] = [8,9,10]
	var chooser = helper.new(44)
	var twin = helper.new(44)
	var first: int = chooser.choose(a,1)
	assert(first==twin.choose(a,1))
	var temporary: int = chooser.choose(b,8)
	assert(chooser.choose(a,temporary)==twin.choose(a,first))
	var manual = helper.new(5)
	var roster: Array[int] = [0,1,2,3,4]
	var picked: int = manual.choose(roster,0)
	var unseen: Array[int] = []
	for i: int in roster:
		if i!=0 and i!=picked: unseen.append(i)
	manual.note_visit(roster,unseen[0])
	var last: int = manual.choose(roster,unseen[0])
	assert(last in [unseen[1],unseen[2]])
	var next: int = manual.choose(roster,last)
	assert(next in [unseen[1],unseen[2]] and next!=last)
	var empty: Array[int] = []
	var singleton: Array[int] = [7]
	var duplicates: Array[int] = [1,1,2,2]
	assert(chooser.choose(empty,1)==-1 and chooser.choose(singleton,7)==7)
	assert(chooser.choose(duplicates,1)==2)
	# Reordering a roster must preserve its tour, without touching gameplay RNG.
	var ordered = helper.new(55)
	var reordered = helper.new(55)
	var first_ordered: int = ordered.choose(a,1)
	assert(first_ordered==reordered.choose(a,1))
	var reversed: Array[int] = a.duplicate()
	reversed.reverse()
	assert(ordered.choose(a,first_ordered)==reordered.choose(reversed,first_ordered))
	seed(9182)
	var expected_global := randi()
	seed(9182)
	var isolated = helper.new(19)
	isolated.choose(a,1)
	assert(randi()==expected_global,"menu shuffling must not consume gameplay/global random state")
	assert(picks==6860)
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/track-shuffle.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"seeded_sessions":100,"seeded_picks":picks,"roster_sizes":[2,5,10,30,40],"seeds_per_roster":20,"full_cycles_after_initial_tour":3,"filter_queues_and_manual_visits":true,"empty_singleton_duplicate_and_reordered_rosters":true,"global_rng_unchanged":true},"\t")+"\n")
	file.close()
	print("TRACK_SHUFFLE_FIRST_TOUR_CYCLES_FILTERS_MANUAL_VISITS_AND_EDGE_CASES_PASS picks=",picks)
	quit()
