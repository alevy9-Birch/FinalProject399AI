extends Control

@onready var _variant_option: OptionButton = $CenterContainer/Panel/VBox/VariantOption


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var state := get_node_or_null("/root/GameState")
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("menu_main_open")
	_variant_option.clear()
	if state != null:
		for name in state.VARIANT_NAMES:
			_variant_option.add_item(name)
		_variant_option.selected = clampi(state.selected_rover_variant, 0, max(0, _variant_option.item_count - 1))


func _on_variant_option_item_selected(index: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.selected_rover_variant = index
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("variant_selected_main", str(index))


func _on_start_button_pressed() -> void:
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("menu_main_continue_customization")
	get_tree().change_scene_to_file("res://scenes/CustomizationMenu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
