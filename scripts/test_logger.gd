extends Node

## TEMP instrumentation logger for monitored tests.
## Emits structured lines to console for agents to parse quickly.

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 2.0:
		_elapsed = 0.0
		var scene_name: String = "none"
		var scene := get_tree().current_scene
		if scene != null:
			scene_name = scene.name
		print("__LOG__ heartbeat scene=", scene_name)


func log_event(name: String, details: String = "") -> void:
	if details == "":
		print("__LOG__ ", name)
	else:
		print("__LOG__ ", name, " ", details)
