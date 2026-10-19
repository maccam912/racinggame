extends "res://tests/network_bot_client.gd"

func _initialize() -> void:
	link.admission_ticket = OS.get_environment("PR_TEST_TICKET")
	super._initialize()
