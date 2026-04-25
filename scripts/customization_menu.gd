extends Control

@onready var _variant_name_label: Label = $CenterContainer/Panel/VBox/VariantName
@onready var _color_option: OptionButton = $CenterContainer/Panel/VBox/ColorOption
@onready var _preview_root: Node3D = $CenterContainer/Panel/VBox/PreviewContainer/SubViewportContainer/SubViewport/PreviewRoot
@onready var _preview_camera: Camera3D = $CenterContainer/Panel/VBox/PreviewContainer/SubViewportContainer/SubViewport/PreviewRoot/PreviewCamera

var _preview_rover: RigidBody3D


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

	_variant_name_label.text = "Variant: %s" % state.VARIANT_NAMES[state.selected_rover_variant]

	_color_option.clear()
	for color_name in state.COLOR_NAMES:
		_color_option.add_item(color_name)
	_color_option.selected = clampi(state.selected_color_index, 0, max(0, _color_option.item_count - 1))


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
	_set_preview_variant(rover, state.selected_rover_variant)
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
