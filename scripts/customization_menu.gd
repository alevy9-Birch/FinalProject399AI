extends Control

@onready var _variant_name_label: Label = $MarginContainer/Panel/RootMargin/RootVBox/TopRow/RoversSection/VariantName
@onready var _chassis_buttons: Array[Button] = [
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/RoversSection/ChassisCards/Card0/ChassisButton0,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/RoversSection/ChassisCards/Card1/ChassisButton1,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/RoversSection/ChassisCards/Card2/ChassisButton2
]
@onready var _color_option: OptionButton = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/PreviewSection/ControlRow/ColorOption
@onready var _slot_buttons: Array[OptionButton] = [
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotButtonsGrid/SlotButton0,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotButtonsGrid/SlotButton1,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotButtonsGrid/SlotButton2,
	$MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/SlotButtonsGrid/SlotButton3
]
@onready var _upgrade_effects: RichTextLabel = $MarginContainer/Panel/RootMargin/RootVBox/TopRow/UpgradeSection/UpgradeEffects
@onready var _stats_summary: Label = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/StatsSummary
@onready var _speed_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/SpeedBar
@onready var _drive_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/DriveBar
@onready var _turn_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/TurnBar
@onready var _fuel_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/FuelBar
@onready var _power_bar: ProgressBar = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/StatsSection/PowerBar
@onready var _preview_root: Node3D = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/PreviewSection/PreviewContainer/SubViewportContainer/SubViewport/PreviewRoot
@onready var _preview_camera: Camera3D = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/PreviewSection/PreviewContainer/SubViewportContainer/SubViewport/PreviewRoot/PreviewCamera
@onready var _back_button: Button = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/PreviewSection/ControlRow/BackButton
@onready var _start_button: Button = $MarginContainer/Panel/RootMargin/RootVBox/BottomRow/PreviewSection/ControlRow/StartButton

var _preview_rover: RigidBody3D
var _ui_sfx_player: AudioStreamPlayer
var _chassis_click_stream: AudioStreamWAV
var _slot_click_stream: AudioStreamWAV
var _ui_hover_stream: AudioStreamWAV


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_ui_audio()
	_setup_hover_sfx_connections()
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
	_apply_preview_chassis_geometry(rover, state.selected_chassis_index)
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
	_play_ui_sfx(_chassis_click_stream)
	state.selected_chassis_index = index
	_variant_name_label.text = "Chassis: %s" % state.CHASSIS_NAMES[state.selected_chassis_index]
	_refresh_all_ui()
	_apply_selection_to_rover(_preview_rover)


func _on_slot_dropdown_item_selected(index: int, slot_idx: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	if slot_idx >= state.get_unlocked_slot_count():
		return
	var selected_upgrade: String = _slot_buttons[slot_idx].get_item_text(index)
	state.set_upgrade_in_slot(slot_idx, selected_upgrade)
	_play_ui_sfx(_slot_click_stream)
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
	for i in range(_slot_buttons.size()):
		_slot_buttons[i].clear()
		if i >= unlocked:
			_slot_buttons[i].disabled = true
			_slot_buttons[i].add_item("LOCKED")
			_slot_buttons[i].selected = 0
		else:
			_slot_buttons[i].disabled = false
			for upgrade_name in state.UPGRADE_NAMES:
				_slot_buttons[i].add_item(upgrade_name)
			var selected_upgrade: String = state.selected_upgrades[i]
			for idx in range(_slot_buttons[i].item_count):
				var text: String = _slot_buttons[i].get_item_text(idx)
				if text == selected_upgrade:
					_slot_buttons[i].selected = idx
					break
			_slot_buttons[i].tooltip_text = "Slot %d - click to choose component" % [i + 1]


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
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("start_new_run"):
		state.start_new_run()
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


func _apply_preview_chassis_geometry(rover: Node3D, chassis_idx: int) -> void:
	var body_scale: float = 1.0
	var half_track: float = 0.95
	var wheel_y: float = -0.82
	var front_z: float = -1.2
	var back_z: float = 1.2
	var use_mid_axle: bool = false
	match chassis_idx:
		0:
			body_scale = 0.9
			half_track = 0.9
			front_z = -1.05
			back_z = 1.05
		1:
			body_scale = 1.0
			half_track = 0.95
			front_z = -1.2
			back_z = 1.2
		2:
			body_scale = 1.22
			half_track = 1.1
			front_z = -1.45
			back_z = 1.45
			use_mid_axle = true
	var variant_root: Node3D = rover.get_node_or_null("VariantRoot/VariantA") as Node3D
	if variant_root != null:
		variant_root.scale = Vector3.ONE * body_scale
	var pivots: Dictionary = {
		"WheelVisuals/FrontLeftWheelPivot": Vector3(-half_track, wheel_y, front_z),
		"WheelVisuals/FrontRightWheelPivot": Vector3(half_track, wheel_y, front_z),
		"WheelVisuals/BackLeftWheelPivot": Vector3(-half_track, wheel_y, back_z),
		"WheelVisuals/BackRightWheelPivot": Vector3(half_track, wheel_y, back_z),
		"WheelVisuals/MidLeftWheelPivot": Vector3(-half_track, wheel_y, 0.0),
		"WheelVisuals/MidRightWheelPivot": Vector3(half_track, wheel_y, 0.0)
	}
	for path in pivots.keys():
		var pivot: Node3D = rover.get_node_or_null(path) as Node3D
		if pivot != null:
			pivot.position = pivots[path]
	var mid_left: Node3D = rover.get_node_or_null("WheelVisuals/MidLeftWheelPivot") as Node3D
	var mid_right: Node3D = rover.get_node_or_null("WheelVisuals/MidRightWheelPivot") as Node3D
	if mid_left != null:
		mid_left.visible = use_mid_axle
	if mid_right != null:
		mid_right.visible = use_mid_axle


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


func _setup_ui_audio() -> void:
	_ui_sfx_player = AudioStreamPlayer.new()
	_ui_sfx_player.bus = "Master"
	_ui_sfx_player.volume_db = -9.0
	add_child(_ui_sfx_player)

	# Soft, low UI "module select" tone.
	_chassis_click_stream = _build_sci_fi_click_stream(330.0, 280.0, 0.075, 0.30)
	# Slightly brighter companion tone for slot selection.
	_slot_click_stream = _build_sci_fi_click_stream(410.0, 350.0, 0.065, 0.34)
	# Subtle hover tick used across selection UI buttons.
	_ui_hover_stream = _build_sci_fi_click_stream(500.0, 540.0, 0.045, 0.26)


func _setup_hover_sfx_connections() -> void:
	for button in _chassis_buttons:
		if button != null and not button.mouse_entered.is_connected(_on_selection_button_hovered):
			button.mouse_entered.connect(_on_selection_button_hovered)
	for button in _slot_buttons:
		if button != null and not button.mouse_entered.is_connected(_on_selection_button_hovered):
			button.mouse_entered.connect(_on_selection_button_hovered)
	for button in [_back_button, _start_button]:
		if button != null and not button.mouse_entered.is_connected(_on_selection_button_hovered):
			button.mouse_entered.connect(_on_selection_button_hovered)


func _on_selection_button_hovered() -> void:
	_play_ui_sfx(_ui_hover_stream)


func _play_ui_sfx(stream: AudioStreamWAV) -> void:
	if _ui_sfx_player == null or stream == null:
		return
	_ui_sfx_player.stream = stream
	_ui_sfx_player.play()


func _build_sci_fi_click_stream(start_freq: float, end_freq: float, duration_sec: float, brightness: float) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var sample_count: int = int(duration_sec * sample_rate)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)

	var phase: float = 0.0
	var two_pi: float = PI * 2.0
	var attack_samples: int = max(1, int(sample_count * 0.06))
	var decay_start: int = int(sample_count * 0.28)

	for i in range(sample_count):
		var t: float = float(i) / float(max(1, sample_count - 1))
		var freq: float = lerpf(start_freq, end_freq, t)
		phase += two_pi * (freq / float(sample_rate))

		var env: float = 1.0
		if i < attack_samples:
			env = float(i) / float(attack_samples)
		elif i > decay_start:
			var rem: float = float(sample_count - i) / float(max(1, sample_count - decay_start))
			env = rem * rem

		# Keep overtones tight to avoid laser-like pitch sweeps.
		var fundamental: float = sin(phase)
		var overtone: float = sin(phase * 1.52 + 0.17) * brightness
		var body: float = sin(phase * 0.50) * 0.18
		var sample: float = (fundamental * 0.74 + overtone * 0.16 + body * 0.10) * env
		var sample_i16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)

		pcm[i * 2] = sample_i16 & 0xFF
		pcm[i * 2 + 1] = (sample_i16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm
	return stream
