class_name IrohRooms
extends Node
## Foreground listen host: the existing authority and a normal predicted client.

signal changed
signal failed(message: String)
var rendezvous := IrohRendezvous.new()
var authority: RoomServer
var authority_world: SubViewport
var code: String = ""
var revoke_token: String = ""
var expires_at: float = 0
var endpoint: String = ""
var generation: int = 0
var busy: bool = false


func _ready() -> void:
	add_child(rendezvous)


func host() -> Dictionary:
	close()
	if not IrohTransport.available(): return {"ok":false,"message":I18n.t("online.iroh_unavailable")}
	var peer := IrohTransport.server()
	if peer==null: return {"ok":false,"message":I18n.t("online.iroh_unavailable")}
	endpoint = str(peer.call("connection_string"))
	if not IrohTransport.valid_endpoint(endpoint):
		peer.close()
		return {"ok":false,"message":I18n.t("online.iroh_unavailable")}
	authority = RoomServer.new()
	authority.embedded = true
	authority.wire.replace_peer(peer)
	authority.lobby.region = "Iroh room"
	authority.stopped.connect(func() -> void:
		if is_instance_valid(authority):
			failed.emit(I18n.t("online.iroh_host_closed")))
	authority_world = SubViewport.new()
	authority_world.own_world_3d = true
	authority_world.size = Vector2i(2,2)
	authority_world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(authority_world)
	authority_world.add_child(authority)
	if not authority.startup_error.is_empty():
		close()
		return {"ok":false,"message":I18n.t("online.iroh_unavailable")}
	var expected := generation
	var reply := await regenerate()
	if not reply.ok and expected==generation: close()
	return reply


func regenerate() -> Dictionary:
	if busy or not is_instance_valid(authority): return {"ok":false,"message":I18n.t("online.iroh_host_closed")}
	busy = true
	var expected := generation
	var reply := await rendezvous.register(endpoint)
	if expected!=generation:
		if reply.ok: rendezvous.revoke(str(reply.payload.get("code","")),str(reply.payload.get("revoke_token","")))
		return {"ok":false,"message":I18n.t("online.iroh_host_closed")}
	busy = false
	if not reply.ok: return reply
	var payload: Dictionary = reply.payload
	var new_code := IrohRendezvous.normalize(str(payload.get("code","")))
	var token := str(payload.get("revoke_token",""))
	var expiry := str(payload.get("expires_at",""))
	if not IrohRendezvous.valid_code(new_code) or token.is_empty() or token.length()>256 or payload.get("endpoint_id")!=endpoint or payload.get("session_id")!=IrohRendezvous.session_id() or expiry.is_empty():
		rendezvous.revoke(new_code,token)
		return {"ok":false,"message":I18n.t("online.iroh_service_error")}
	var old_code := code
	var old_token := revoke_token
	code = new_code
	revoke_token = token
	expires_at = Time.get_unix_time_from_datetime_string(expiry.trim_suffix("Z"))
	if not old_code.is_empty(): rendezvous.revoke(old_code,old_token)
	if "--network-evidence" in OS.get_cmdline_user_args():
		print("PACIFIC_RUSH_IROH_ROOM "+JSON.stringify({"code":code,"endpoint":endpoint,"expires_at":expires_at}))
	changed.emit()
	return {"ok":true,"endpoint":endpoint}


func close() -> void:
	generation += 1
	busy = false
	if is_instance_valid(authority):
		authority.wire.close()
		authority.set_physics_process(false)
		authority.queue_free()
	authority = null
	if is_instance_valid(authority_world): authority_world.queue_free()
	authority_world = null
	if not code.is_empty() and is_inside_tree(): rendezvous.revoke(code,revoke_token)
	code = ""
	revoke_token = ""
	endpoint = ""
	expires_at = 0
