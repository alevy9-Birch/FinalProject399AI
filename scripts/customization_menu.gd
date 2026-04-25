extends Control

@onready var _variant_name_label: Label = $CenterContainer/Panel/VBox/VariantName
@onready var _chassis_option: OptionButton = $CenterContainer/Panel/VBox/ChassisOption
@onready var _color_option: OptionButton = $CenterContainer/Panel/VBox/ColorOption
@onready var _stats_label: Label = $CenterContainer/Panel/VBox/StatsLabel
@onready var _slot_buttons: Array[Button] = [
	$CenterContainer/Panel/VBox/UpgradeSection/SlotsGrid/SlotButton0,
	$CenterContainer/Panel/VBox/UpgradeSection/SlotsGrid/SlotButton1,
	$CenterContainer/Panel/VBox/UpgradeSection/SlotsGrid/SlotButton2,
	$CenterContainer/Panel/VBox/UpgradeSection/SlotsGrid/SlotButton3
]
@onready var _selected_slot_label: Label = $CenterContainer/Panel/VBox/UpgradeSection/UpgradePickerRow/SelectedSlotLabel
@onready var _upgrade_option: OptionButton = $CenterContainer/Panel/VBox/UpgradeSection/UpgradePickerRow/UpgradeOption
@onready var _preview_root: Node3D = $CenterContainer/Panel/VBox/PreviewContainer/SubViewportContainer/SubViewport/PreviewRoot
@onready var _preview_camera: Camera3D = $CenterContainer/Panel/VBox/PreviewContainer/SubViewportContainer/SubViewport/PreviewRoot/PreviewCamera

var _preview_rover: RigidBody3D
var _selected_slot_idx: int = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_ui_from_state()
	_spawn_preview_rover()
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("menu_custom_open")


func _process(delta: float) -> void:
	# Keep cursor visible in customization even if any spawned preview node tries to capture it.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _preview_rover != null:
		_preview_rover.rotate_y(0.35 * delta)
		_preview_camera.look_at(Vector3(0, 0.05, 0), Vector3.UP)


func _setup_ui_from_state() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return

	_variant_name_label.text = "Chassis: %s" % state.CHASSIS_NAMES[state.selected_chassis_index]

	_chassis_option.clear()
	for chassis_name in state.CHASSIS_NAMES:
		_chassis_option.add_item(chassis_name)
	_chassis_option.selected = clampi(state.selected_chassis_index, 0, max(0, _chassis_option.item_count - 1))

	_color_option.clear()
	for color_name in state.COLOR_NAMES:
		_color_option.add_item(color_name)
	_color_option.selected = clampi(state.selected_color_index, 0, max(0, _color_option.item_count - 1))

	_upgrade_option.clear()
	for upgrade_name in state.UPGRADE_NAMES:
		_upgrade_option.add_item(upgrade_name)

	_refresh_slot_buttons()
	_refresh_stats_label()
	_update_selected_slot_ui()


func _spawn_preview_rover() -> void:
	var rover_scene: PackedScene = load("res://scenes/Rover.tscn")
	_preview_rover = rover_scene.instantiate() as RigidBody3D
	# Preview should never run gameplay logic or camera scripts.
	_prepare_preview_instance(_preview_rover)
	_preview_root.add_child(_preview_rover)
	_preview_rover.global_position = Vector3.ZERO
	_apply_selection_to_rover(_preview_rover)


func _apply_selection_to_rover(rover: RigidBody3D) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	_set_preview_variant(rover, 0)
	_set_preview_color(rover, state.COLOR_VALUES[state.selected_color_index])


func _on_color_option_item_selected(index: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	state.selected_color_index = index
	_apply_selection_to_rover(_preview_rover)
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("color_selected", str(index))


func _on_chassis_option_item_selected(index: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	state.selected_chassis_index = index
	_variant_name_label.text = "Chassis: %s" % state.CHASSIS_NAMES[state.selected_chassis_index]
	_refresh_slot_buttons()
	_refresh_stats_label()
	_apply_selection_to_rover(_preview_rover)
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("chassis_selected", str(index))


func _on_slot_button_pressed(slot_idx: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	if slot_idx >= state.get_unlocked_slot_count():
		return
	_selected_slot_idx = slot_idx
	_update_selected_slot_ui()


func _on_apply_upgrade_button_pressed() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	if _selected_slot_idx >= state.get_unlocked_slot_count():
		return
	var selected_upgrade: String = _upgrade_option.get_item_text(_upgrade_option.selected)
	state.set_upgrade_in_slot(_selected_slot_idx, selected_upgrade)
	_refresh_slot_buttons()
	_refresh_stats_label()
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("upgrade_equipped", "slot=%d item=%s" % [_selected_slot_idx, selected_upgrade])


func _on_back_button_pressed() -> void:
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("menu_custom_back_main")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_start_button_pressed() -> void:
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("menu_custom_start_game")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _prepare_preview_instance(rover: RigidBody3D) -> void:
	# Remove rover camera rig so no preview child captures mouse.
	var cam_rig: Node = rover.get_node_or_null("CameraRig")
	if cam_rig != null:
		cam_rig.free()
	# Remove gameplay-only helper nodes from preview.
	for node_name in ["GroundRays", "ResetButton"]:
		var n: Node = rover.get_node_or_null(node_name)
		if n != null:
			n.free()
	# Disable rover gameplay script for preview.
	rover.set_script(null)
	rover.freeze = true
	rover.linear_velocity = Vector3.ZERO
	rover.angular_velocity = Vector3.ZERO
	rover.sleeping = true


func _set_preview_variant(rover: Node3D, variant_index: int) -> void:
	var root: Node = rover.get_node_or_null("VariantRoot")
	if root == null:
		return
	var idx: int = clampi(variant_index, 0, root.get_child_count() - 1)
	for i in range(root.get_child_count()):
		var child := root.get_child(i) as Node3D
		if child != null:
			child.visible = i == idx


func _refresh_slot_buttons() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var unlocked_slots: int = state.get_unlocked_slot_count()
	_selected_slot_idx = clampi(_selected_slot_idx, 0, max(0, unlocked_slots - 1))
	for i in range(_slot_buttons.size()):
		var button: Button = _slot_buttons[i]
		if i >= unlocked_slots:
			button.text = "SLOT %d\nLOCKED" % [i + 1]
			button.disabled = true
			button.modulate = Color(0.45, 0.45, 0.5, 1.0)
			continue
		button.disabled = false
		button.modulate = Color(1, 1, 1, 1)
		var upgrade_name: String = state.selected_upgrades[i]
		button.text = "SLOT %d\n%s" % [i + 1, upgrade_name]


func _update_selected_slot_ui() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	_selected_slot_label.text = "Selected Slot: %d" % [_selected_slot_idx + 1]
	for i in range(_slot_buttons.size()):
		if i == _selected_slot_idx and i < state.get_unlocked_slot_count():
			_slot_buttons[i].self_modulate = Color(0.8, 1.0, 1.0, 1.0)
		else:
			_slot_buttons[i].self_modulate = Color(1, 1, 1, 1)
	var current_upgrade: String = state.selected_upgrades[_selected_slot_idx]
	for option_i in range(_upgrade_option.item_count):
		if _upgrade_option.get_item_text(option_i) == current_upgrade:
			_upgrade_option.selected = option_i
			break


func _refresh_stats_label() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var stats: Dictionary = state.get_final_rover_stats()
	_stats_label.text = "Stats: Spd %.1f | Drive %.0f | Turn %.0f | Mass %.1f | Fuel %.0f | Air %.0f" % [
		float(stats.get("max_drive_speed", 0.0)),
		float(stats.get("drive_force", 0.0)),
		float(stats.get("turn_torque", 0.0)),
		float(stats.get("mass", 0.0)),
		float(stats.get("thruster_fuel_capacity", 0.0)),
		float(stats.get("air_torque", 0.0))
	]


func _set_preview_color(rover: Node, color: Color) -> void:
	_recolor_recursive(rover, color)


func _recolor_recursive(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node: MeshInstance3D = child
			var mat: Material = mesh_node.material_override
			if mat is StandardMaterial3D:
				var std_mat: StandardMaterial3D = mat
				var n: String = mesh_node.name.to_lower()
				var recolorable: bool = n.contains("frame") or n.contains("brace") or n.contains("skirt") or n.contains("mast")
				if recolorable:
					var duplicate_mat: StandardMaterial3D = std_mat.duplicate() as StandardMaterial3D
					duplicate_mat.albedo_color = color
					mesh_node.material_override = duplicate_mat
		_recolor_recursive(child, color)
