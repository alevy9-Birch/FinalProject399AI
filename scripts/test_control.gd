extends Node

## TEMP TEST HARNESS (remove later):
## Global key handling so T works in all scenes.

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("end_test"):
		print("__END_TEST_REQUEST__")
		var logger := get_node_or_null("/root/TestLogger")
		if logger != null:
			logger.log_event("end_test_pressed")
		get_tree().quit()
