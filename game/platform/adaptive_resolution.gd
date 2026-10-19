class_name AdaptiveResolution
extends RefCounted
## Presentation budget only. Selected settings and simulation cadence never change.
var selected: int = 100
var current: int = 100
var enabled: bool = false
var target_seconds: float = 1.0/60
var slow_seconds: float = 0
var fast_seconds: float = 0
var changes: int = 0

func configure(scale: int, adaptive: bool, cap: int) -> void:
	var target := 1.0/maxi(1,cap)
	if selected==scale and enabled==adaptive and is_equal_approx(target_seconds,target): return
	selected = scale
	current = scale
	enabled = adaptive
	target_seconds = target
	reset_window()

func reset_window() -> void:
	slow_seconds = 0
	fast_seconds = 0

func sample(work_seconds: float, interval_seconds: float, active: bool) -> bool:
	if not enabled or not active or not is_finite(work_seconds) or work_seconds<=0 or not is_finite(interval_seconds) or interval_seconds<=0 or interval_seconds>.5:
		reset_window()
		return false
	# Work excludes the frame limiter. Missed presentation deadlines still
	# count as overload when mobile GLES cannot provide GPU timer queries.
	var overloaded := maxf(work_seconds,interval_seconds)>target_seconds*1.15
	var headroom := work_seconds<target_seconds*.85 and not overloaded
	slow_seconds = slow_seconds+interval_seconds if overloaded else 0.0
	fast_seconds = fast_seconds+interval_seconds if headroom else 0.0
	var previous := current
	if slow_seconds>=2.0-.000001:
		current = maxi(mini(selected,60),current-10)
		reset_window()
	elif fast_seconds>=10.0-.000001:
		current = mini(selected,current+10)
		reset_window()
	if previous==current: return false
	changes += 1
	return true
