extends SceneTree


func _initialize() -> void:
	assert(PlayerName.nfc("Café") == "Café")
	assert(PlayerName.nfc("Å") == "Å")
	assert(PlayerName.nfc("각") == "각")
	assert(PlayerName.nfc("é") == "é")
	assert(PlayerName.validate("👨‍👩‍👧‍👦ab").valid)
	assert(not PlayerName.validate("ab").valid)
	assert(not PlayerName.validate("<color>").valid)
	assert(not PlayerName.validate("A\nB").valid)
	assert(not PlayerName.validate("👨‍👩‍👧‍👦".repeat(4)).valid)
	print("Player names: NFC, Hangul, grapheme bounds, byte cap and control/markup rejection pass")
	quit()
