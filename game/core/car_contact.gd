class_name CarContact
extends RefCounted


static func resolve(states: Array[VehicleState], queries: Array[WorldQuery], local_slot: int = -1) -> void:
	var displacement: Array[float] = []
	var impulses: Array[Vector3] = []
	for _state: VehicleState in states:
		displacement.append(0)
		impulses.append(Vector3.ZERO)
	for _pass in range(2):
		for a in range(states.size()):
			for b in range(a + 1, states.size()):
				# Prediction only resolves pairs involving the local driver. Remote
				# states are disposable estimates; authority still resolves all pairs.
				if local_slot >= 0 and a != local_slot and b != local_slot:
					continue
				var first := states[a]
				var second := states[b]
				if first.ghost_ticks > 0 or second.ghost_ticks > 0 or first.finished or second.finished or first.dnf_reason != "" or second.dnf_reason != "":
					continue
				if absf(first.position.y - second.position.y) > 1.1 or first.position.distance_squared_to(second.position) > 25:
					continue
				var contact := overlap(first, second)
				if contact.is_empty():
					continue
				var normal: Vector3 = contact.normal
				for index in [a, b]:
					var amount := minf(contact.depth * .5, .25 - displacement[index])
					var correction := normal * amount * (-1.0 if index == a else 1.0)
					var state := states[index]
					var swept := queries[index].sweep(state.position, correction / VehicleSim.DT, state.yaw, VehicleSim.DT, false)
					state.position = swept.position
					displacement[index] += amount
				var closing := (second.velocity - first.velocity).dot(normal)
				if closing < 0:
					var impulse := normal * (-closing * 1.05 / 2)
					for index in [a, b]:
						var proposed: Vector3 = impulses[index] + impulse * (-1.0 if index == a else 1.0)
						var bounded := proposed.limit_length(4)
						states[index].velocity += bounded - impulses[index]
						impulses[index] = bounded
				if first.contact_ticks == 0 or second.contact_ticks == 0:
					first.events.append("bump")
					second.events.append("bump")
				first.contact_ticks = 12
				second.contact_ticks = 12


static func footprint(state: VehicleState) -> PackedVector3Array:
	var result := PackedVector3Array()
	var basis := Basis(Vector3.UP, -state.yaw)
	for index in range(4):
		var centers := [Vector2(.7, 1.85), Vector2(-.7, 1.85), Vector2(-.7, -1.85), Vector2(.7, -1.85)]
		for offset in range(4):
			var angle := deg_to_rad(index * 90 + offset * 30)
			var point: Vector2 = centers[index] + Vector2(cos(angle), sin(angle)) * .25
			result.append(state.position + basis * Vector3(point.x, 0, point.y))
	return result


static func overlap(a: VehicleState, b: VehicleState) -> Dictionary:
	var first := footprint(a)
	var second := footprint(b)
	var depth := INF
	var normal := Vector3.ZERO
	for polygon: PackedVector3Array in [first, second]:
		for index in range(polygon.size()):
			var edge := polygon[(index + 1) % polygon.size()] - polygon[index]
			var axis := Vector3(edge.z, 0, -edge.x).normalized()
			var lo_a := INF
			var hi_a := -INF
			var lo_b := INF
			var hi_b := -INF
			for p: Vector3 in first:
				lo_a = minf(lo_a, p.dot(axis))
				hi_a = maxf(hi_a, p.dot(axis))
			for p: Vector3 in second:
				lo_b = minf(lo_b, p.dot(axis))
				hi_b = maxf(hi_b, p.dot(axis))
			var amount := minf(hi_a, hi_b) - maxf(lo_a, lo_b)
			if amount <= 0:
				return {}
			if amount < depth:
				depth = amount
				normal = axis * (1 if (b.position - a.position).dot(axis) >= 0 else -1)
	return {"normal": normal, "depth": depth}
