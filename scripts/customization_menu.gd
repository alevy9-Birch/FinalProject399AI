extends Control

@onready var _variant_name_label: Label = $MarginContainer/Panel/RootMargin/RootVBox/TopRow/RoversSection/VariantName
@onready var _chassis_buttons: Array[Button] = [
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/RoversSection/ChassisCards/Card0/ChassisButton0,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/RoversSection/ChassisCards/Card1/ChassisButton1,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/RoversSection/ChassisCards/Card2/ChassisButton2
]
@onready var _color_option: OptionButton = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/PreviewSection/ControlRow/ColorOption
@onready var _slot_buttons: Array[Button] = [
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotButtonsGrid/SlotButton0,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotButtonsGrid/SlotButton1,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotButtonsGrid/SlotButton2,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotButtonsGrid/SlotButton3
]
@onready var _slot_upgrade_option: OptionButton = $MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotPickerRow/SlotUpgradeOption
@onready var _selected_slot_label: Label = $MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotPickerRow/SelectedSlotLabel
@onready var _upgrade_effects: RichTextLabel = $MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/UpgradeEffects
@onready var _stats_summary: Label = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/StatsSummary
@onready var _speed_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/SpeedBar
@onready var _drive_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/DriveBar
@onready var _turn_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/TurnBar
@onready var _fuel_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/FuelBar
@onready var _power_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/PowerBar
@onready var _preview_root: Node3D = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/PreviewSection/PreviewContainer/SubViewportContainer/SubViewport/PreviewRoot
@onready var _preview_camera: Camera3D = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/PreviewSection/PreviewContainer/SubViewportContainer/SubViewport/PreviewRoot/PreviewCamera

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
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _preview_rover != null:
		_preview_rover.rotate_y(0.35 * delta)
		_preview_camera.look_at(Vector3(0, 0.05, 0), Vector3.UP)


func _setup_ui_from_state() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	_color_option.clear()
	for color_name in state.COLOR_NAMES:
		_color_option.add_item(color_name)
	_color_option.selected = clampi(state.selected_color_index, 0, max(0, _color_option.item_count - 1))
	_slot_upgrade_option.clear()
	for upgrade_name in state.UPGRADE_NAMES:
		_slot_upgrade_option.add_item(upgrade_name)
	_refresh_all_ui()


func _refresh_all_ui() -> void:
	_refresh_chassis_buttons()
	_refresh_slot_buttons()
	_refresh_stats()
	_refresh_upgrade_effects()


func _spawn_preview_rover() -> void:
	var rover_scene: PackedScene = load("res://scenes/Rover.tscn")
	_preview_rover = rover_scene.instantiate() as RigidBody3D
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


func _on_chassis_card_pressed(index: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	state.selected_chassis_index = index
	_variant_name_label.text = "Chassis: %s" % state.CHASSIS_NAMES[state.selected_chassis_index]
	_refresh_all_ui()
	_apply_selection_to_rover(_preview_rover)


func _on_slot_button_pressed(slot_idx: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	if slot_idx >= state.get_unlocked_slot_count():
		return
	_selected_slot_idx = slot_idx
	_selected_slot_label.text = "Slot %d" % (_selected_slot_idx + 1)
	var current: String = state.selected_upgrades[_selected_slot_idx]
	for i in range(_slot_upgrade_option.item_count):
		if _slot_upgrade_option.get_item_text(i) == current:
			_slot_upgrade_option.selected = i
			break


func _on_slot_upgrade_option_selected(index: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	if _selected_slot_idx >= state.get_unlocked_slot_count():
		return
	var selected_upgrade: String = _slot_upgrade_option.get_item_text(index)
	state.set_upgrade_in_slot(_selected_slot_idx, selected_upgrade)
	_refresh_all_ui()


func _refresh_chassis_buttons() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	_variant_name_label.text = "Chassis: %s" % state.CHASSIS_NAMES[state.selected_chassis_index]
	for i in range(_chassis_buttons.size()):
		_chassis_buttons[i].self_modulate = Color(0.72, 1.0, 1.0, 1.0) if i == state.selected_chassis_index else Color(1, 1, 1, 1)


func _refresh_slot_buttons() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var unlocked: int = state.get_unlocked_slot_count()
	_selected_slot_idx = clampi(_selected_slot_idx, 0, max(0, unlocked - 1))
	for i in range(_slot_buttons.size()):
		if i >= unlocked:
			_slot_buttons[i].text = "LOCKED"
			_slot_buttons[i].disabled = true
		else:
			_slot_buttons[i].disabled = false
			_slot_buttons[i].text = "Slot %d\n%s" % [i + 1, state.selected_upgrades[i]]
	_selected_slot_label.text = "Slot %d" % (_selected_slot_idx + 1)


func _refresh_stats() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var stats: Dictionary = state.get_final_rover_stats()
	_speed_bar.value = clampf(float(stats.get("max_drive_speed", 0.0)) / 40.0, 0.0, 1.0)
	_drive_bar.value = clampf(float(stats.get("drive_force", 0.0)) / 1000.0, 0.0, 1.0)
	_turn_bar.value = clampf(float(stats.get("turn_torque", 0.0)) / 150.0, 0.0, 1.0)
	_fuel_bar.value = clampf(float(stats.get("thruster_fuel_capacity", 0.0)) / 220.0, 0.0, 1.0)
	_power_bar.value = clampf(float(stats.get("battery_max_power", 0.0)) / 220.0, 0.0, 1.0)
	_stats_summary.text = "Mass %.1f | Air %.0f | Fuel %.0f | Power %.0f" % [
		float(stats.get("mass", 0.0)),
		float(stats.get("air_torque", 0.0)),
		float(stats.get("thruster_fuel_capacity", 0.0)),
		float(stats.get("battery_max_power", 0.0))
	]


func _refresh_upgrade_effects() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var lines: PackedStringArray = []
	var unlocked: int = state.get_unlocked_slot_count()
	for i in range(unlocked):
		var upg: String = state.selected_upgrades[i]
		lines.append("[b]Slot %d: %s[/b] - %s" % [i + 1, upg, state.get_upgrade_description(upg)])
	_upgrade_effects.text = "\n".join(lines)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _prepare_preview_instance(rover: RigidBody3D) -> void:
	var cam_rig: Node = rover.get_node_or_null("CameraRig")
	if cam_rig != null:
		cam_rig.free()
	for node_name in ["GroundRays", "ResetButton"]:
		var n: Node = rover.get_node_or_null(node_name)
		if n != null:
			n.free()
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
