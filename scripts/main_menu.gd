extends Control

@onready var _variant_option: OptionButton = $CenterContainer/Panel/VBox/VariantOption
@onready var _subtitle: Label = $CenterContainer/Panel/VBox/Subtitle
@onready var _alien_presence_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/AlienPresenceValue
@onready var _ore_quantity_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/OreQuantityValue
@onready var _planet_size_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/PlanetSizeValue
@onready var _planet_gravity_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/PlanetGravityValue
@onready var _surface_props_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/SurfacePropsValue
@onready var _yelp_review_value: Label = $CenterContainer/Panel/VBox/MissionBriefingPanel/MissionBriefingVBox/MissionBriefingGrid/YelpReviewValue


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
	_variant_option.disabled = _variant_option.item_count <= 1
	_set_generated_mission_briefing_values()


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
