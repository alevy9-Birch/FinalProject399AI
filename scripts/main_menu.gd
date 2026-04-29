extends Control

@onready var _variant_option: OptionButton = $CenterContainer/Panel/VBox/VariantOption
@onready var _start_button: Button = $CenterContainer/Panel/VBox/StartButton
@onready var _quit_button: Button = $CenterContainer/Panel/VBox/QuitButton
@onready var _subtitle: Label = $CenterContainer/Panel/VBox/Subtitle
@onready var _alien_presence_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/AlienPresenceValue
@onready var _ore_quantity_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/OreQuantityValue
@onready var _planet_size_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/PlanetSizeValue
@onready var _planet_gravity_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/PlanetGravityValue
@onready var _surface_props_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/SurfacePropsValue
@onready var _yelp_review_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/YelpReviewValue

var _menu_sfx_player: AudioStreamPlayer
var _menu_select_stream: AudioStreamWAV
var _menu_confirm_stream: AudioStreamWAV
var _menu_hover_stream: AudioStreamWAV


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_menu_audio()
	_setup_hover_sfx_connections()
	var state := get_node_or_null("/root/GameState")
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("menu_main_open")
	_variant_option.clear()
	if state != null:
		for name in state.VARIANT_NAMES:
			_variant_option.add_item(name)
		_variant_option.selected = clampi(state.selected_rover_variant, 0, max(0, _variant_option.item_count - 1))
	_variant_option.disabled = _variant_option.item_count <= 1
	_set_generated_mission_briefing_values()
	_append_score_summary()


func _on_variant_option_item_selected(index: int) -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.selected_rover_variant = index
	_play_menu_sfx(_menu_select_stream)
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("variant_selected_main", str(index))


func _on_start_button_pressed() -> void:
	_play_menu_sfx(_menu_confirm_stream)
	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("menu_main_continue_customization")
	get_tree().change_scene_to_file("res://scenes/CustomizationMenu.tscn")


func _on_quit_button_pressed() -> void:
	_play_menu_sfx(_menu_confirm_stream)
	get_tree().quit()


func _set_generated_mission_briefing_values() -> void:
	var mission_generator := get_node_or_null("/root/MissionGenerator")
	if mission_generator == null:
		_subtitle.text = "Mission system unavailable"
		_alien_presence_value.text = "--"
		_ore_quantity_value.text = "--"
		_planet_size_value.text = "--"
		_planet_gravity_value.text = "--"
		_surface_props_value.text = "--"
		_yelp_review_value.text = "--"
		return

	var mission: Dictionary = mission_generator.generate_new_mission()
	_subtitle.text = "Destination: %s (%s)" % [
		str(mission.get("planet_name", "Unknown World")),
		mission_generator.get_planet_type_name(int(mission.get("planet_type", 0)))
	]
	_alien_presence_value.text = mission_generator.get_alien_presence_name(int(mission.get("alien_presence", 0)))
	_ore_quantity_value.text = "%s (%d deposits)" % [
		mission_generator.get_ore_quantity_name(int(mission.get("ore_quantity", 0))),
		int(mission.get("ore_node_count", 0))
	]
	var size_name: String = mission_generator.get_planet_size_name(int(mission.get("planet_size_class", 0)))
	var radius: float = float(mission.get("planet_radius", 0.0))
	_planet_size_value.text = "%s (R=%.0fm)" % [size_name, radius]
	var gravity_name: String = mission_generator.get_gravity_name(int(mission.get("gravity_class", 0)))
	var gravity_mult: float = float(mission.get("gravity_multiplier", 1.0))
	_planet_gravity_value.text = "%s (%.2fg)" % [gravity_name, gravity_mult]
	_surface_props_value.text = mission_generator.get_prop_profile_name(int(mission.get("prop_profile", 0)))
	var yelp_score: float = float(mission.get("yelp_score", 2.5))
	var yelp_tagline: String = str(mission.get("yelp_tagline", "Rocky but scenic"))
	_yelp_review_value.text = "%.1f stars - %s" % [yelp_score, yelp_tagline]


func _append_score_summary() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	_subtitle.text += "  |  Last: %d  Best: %d" % [int(state.last_run_score), int(state.best_run_score)]


func _setup_menu_audio() -> void:
	_menu_sfx_player = AudioStreamPlayer.new()
	_menu_sfx_player.bus = "Master"
	_menu_sfx_player.volume_db = -9.0
	add_child(_menu_sfx_player)

	# Deeper, softer UI select tone.
	_menu_select_stream = _build_space_ui_tone(700.0, 320.0, 0.11, 0.48)
	# Slightly stronger confirmation for start/quit actions.
	_menu_confirm_stream = _build_space_ui_tone(860.0, 380.0, 0.14, 0.52)
	# Lightweight hover tick for menu button focus.
	_menu_hover_stream = _build_space_ui_tone(520.0, 560.0, 0.045, 0.32)


func _setup_hover_sfx_connections() -> void:
	for button in [_start_button, _quit_button]:
		if button != null and not button.mouse_entered.is_connected(_on_menu_button_hovered):
			button.mouse_entered.connect(_on_menu_button_hovered)


func _on_menu_button_hovered() -> void:
	_play_menu_sfx(_menu_hover_stream)


func _play_menu_sfx(stream: AudioStreamWAV) -> void:
	if _menu_sfx_player == null or stream == null:
		return
	_menu_sfx_player.stream = stream
	_menu_sfx_player.play()


func _build_space_ui_tone(start_freq: float, end_freq: float, duration_sec: float, brightness: float) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var sample_count: int = int(duration_sec * sample_rate)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)

	var phase: float = 0.0
	var two_pi: float = PI * 2.0
	var attack_samples: int = max(1, int(sample_count * 0.08))
	var decay_start: int = int(sample_count * 0.42)

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

		var fundamental: float = sin(phase)
		var overtone: float = sin(phase * 2.03 + 0.19) * brightness
		var shimmer: float = sin(phase * 3.6) * 0.22 * brightness
		var sample: float = (fundamental * 0.65 + overtone * 0.23 + shimmer * 0.12) * env
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
