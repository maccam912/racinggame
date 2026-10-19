class_name PeerAddress
extends RefCounted


static func parse(value: String) -> Dictionary:
	var pattern := RegEx.new()
	pattern.compile("^(?:\\[([0-9A-Fa-f:]+)\\]|([A-Za-z0-9.-]+)):(\\d{1,5})$")
	var found := pattern.search(value.strip_edges())
	if found == null:
		return {}
	var hostname := found.get_string(1) if found.get_string(1) != "" else found.get_string(2)
	var port := int(found.get_string(3))
	if port < 1 or port > 65535 or hostname.length() > 253 or hostname.begins_with(".") or hostname.ends_with(".") or ".." in hostname:
		return {}
	return {"host":hostname, "port":port}


static func parse_code(value: String) -> Dictionary:
	var normalized := value.strip_edges().replace("-", "").to_upper()
	if normalized == "":
		return {"valid":true, "value":""}
	if normalized.length() != 8:
		return {"valid":false, "value":""}
	for character: String in normalized:
		if not character in "23456789ABCDEFGHJKLMNPQRSTUVWXYZ":
			return {"valid":false, "value":""}
	return {"valid":true, "value":normalized}
