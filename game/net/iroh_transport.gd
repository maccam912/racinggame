class_name IrohTransport
extends RefCounted
## Dynamic calls keep ENet/offline source runs usable before native compilation.

static func available() -> bool:
	if not ClassDB.class_exists("IrohServer") or not ClassDB.class_exists("IrohClient"): return false
	if OS.has_feature("android"):
		return Engine.has_singleton("PacificMobile") and bool(Engine.get_singleton("PacificMobile").call("initializeIroh"))
	return true


static func valid_endpoint(value: String) -> bool:
	if value.length()!=43: return false
	for character in value:
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_": return false
	return true


static func server() -> MultiplayerPeer:
	return ClassDB.class_call_static("IrohServer","start_configured","--iroh-relay-only" in OS.get_cmdline_user_args()) if available() else null


static func client(endpoint: String) -> MultiplayerPeer:
	return ClassDB.class_call_static("IrohClient","connect_configured",endpoint,"--iroh-relay-only" in OS.get_cmdline_user_args()) if available() and valid_endpoint(endpoint) else null
