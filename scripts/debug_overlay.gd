extends CanvasLayer

## TEMP TEST UI (remove later):
## - Reads `res://debug_status.txt` to show live monitor messages in-game.
## - Works with temporary test controls:
##   R = reset vehicle, T = end test.

@export var message_path: String = "res://debug_status.txt"
@export var refresh_interval: float = 0.25

var _time_until_refresh: float = 0.0
var _external_message: String = ""


func _ready() -> void:
	_update_external_message()


func _process(delta: float) -> void:
	_time_until_refresh -= delta
	if _time_until_refresh <= 0.0:
		_time_until_refresh = refresh_interval
		_update_external_message()

	var base_text: String = "TEMP DEBUG UI\nWASD/Arrows: Drive  Space: Thruster  R: Menu  T: End Test"
	if _external_message.strip_edges() != "":
		base_text += "\n\nAgent Message:\n%s" % _external_message
	$Panel/Message.text = base_text


func _update_external_message() -> void:
	if not FileAccess.file_exists(message_path):
		_external_message = "No external message file yet."
		return

	var file: FileAccess = FileAccess.open(message_path, FileAccess.READ)
	if file == null:
		_external_message = "Failed to open external message file."
		return
	_external_message = file.get_as_text().strip_edges()
