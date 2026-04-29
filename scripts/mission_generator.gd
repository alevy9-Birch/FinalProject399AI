extends Node

## Deterministic mission generation for briefing + gameplay.
## Generates enum-style mission descriptors and derived numeric parameters.

enum PlanetType {
	ASTEROID_RUBBLE,
	CRATERED_MOON,
	METALLIC_CORE,
	VOLCANIC_SHARD,
	ICE_DUSTBALL,
	HABITABLE_WORLD,
	DESERT_DUNE,
	TOXIC_SWAMP
}

enum AlienPresence {
	NONE,
	LOW,
	MODERATE,
	HEAVY,
	OVERWHELMING
}

enum OreQuantity {
	SCARCE,
	PATCHY,
	STANDARD,
	RICH,
	BONANZA
}

enum PlanetSizeClass {
	TINY,
	SMALL,
	MEDIUM,
	LARGE,
	HUGE
}

enum GravityClass {
	MICRO_G,
	LOW_G,
	EARTHLIKE,
	HEAVY_G,
	CRUSHING
}

enum PropProfile {
	BARREN,
	CRYSTAL_FIELD,
	ANCIENT_RUINS,
	TREE_GROVES,
	ICE_SPIKES,
	BASALT_COLUMNS,
	FUNGAL_BLOOM
}

const PLANET_TYPE_NAMES: PackedStringArray = [
	"Asteroid Rubble",
	"Cratered Moon",
	"Metallic Core",
	"Volcanic Shard",
	"Ice Dustball",
	"Habitable World",
	"Desert Dune",
	"Toxic Swamp"
]

const ALIEN_PRESENCE_NAMES: PackedStringArray = [
	"None",
	"Low Patrol Activity",
	"Moderate Patrol Activity",
	"Heavy Presence",
	"Overwhelming Threat"
]

const ORE_QUANTITY_NAMES: PackedStringArray = [
	"Scarce Veins",
	"Patchy Deposits",
	"Standard Deposits",
	"Rich Veins",
	"Bonanza Density"
]

const PLANET_SIZE_NAMES: PackedStringArray = [
	"Tiny",
	"Small",
	"Medium",
	"Large",
	"Huge"
]

const GRAVITY_CLASS_NAMES: PackedStringArray = [
	"Micro-G",
	"Low-G",
	"Earthlike",
	"Heavy-G",
	"Crushing"
]

const PROP_PROFILE_NAMES: PackedStringArray = [
	"Barren",
	"Crystal Fields",
	"Ancient Ruins",
	"Tree Groves",
	"Ice Spikes",
	"Basalt Columns",
	"Fungal Bloom"
]

var current_mission: Dictionary = {}


func _ready() -> void:
	if current_mission.is_empty():
		generate_new_mission()


func generate_new_mission(seed: int = -1) -> Dictionary:
	var mission_seed: int = seed
	if mission_seed < 0:
		mission_seed = randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed

	var planet_type: int = _roll_planet_type(rng)
	var size_class: int = _roll_size_class(rng, planet_type)
	var gravity_class: int = _roll_gravity_class(rng, planet_type, size_class)
	var ore_quantity: int = _roll_ore_quantity(rng, planet_type)
	var alien_presence: int = _roll_alien_presence(rng, planet_type)
	var prop_profile: int = _roll_prop_profile(rng, planet_type)

	var gravity_multiplier: float = _gravity_multiplier_for_class(gravity_class)
	var radius: float = _radius_for_size_class(size_class, rng)
	var terrain_profile: Dictionary = _terrain_profile_for_type(rng, planet_type)
	var ore_node_count: int = _ore_count_for_quantity(ore_quantity, size_class, rng)
	var alien_budget: int = _alien_budget_for_presence(alien_presence, size_class, rng)
	var alien_interval: float = _alien_interval_for_presence(alien_presence, rng)
	var prop_density: float = _prop_density_for_profile(prop_profile, size_class, rng)
	var planet_name: String = _generate_planet_name(rng, planet_type)

	var yelp: Dictionary = _compute_yelp(ore_quantity, alien_presence, gravity_class, planet_type, rng)

	current_mission = {
		"mission_seed": mission_seed,
		"planet_name": planet_name,
		"planet_type": planet_type,
		"alien_presence": alien_presence,
		"ore_quantity": ore_quantity,
		"planet_size_class": size_class,
		"gravity_class": gravity_class,
		"prop_profile": prop_profile,
		"planet_radius": radius,
		"gravity_multiplier": gravity_multiplier,
		"terrain_profile": terrain_profile,
		"ore_node_count": ore_node_count,
		"ore_yield_range": Vector2i(1, 3 + ore_quantity),
		"alien_spawn_budget": alien_budget,
		"alien_spawn_interval": alien_interval,
		"prop_density": prop_density,
		"yelp_score": yelp["score"],
		"yelp_tagline": yelp["tagline"]
	}

	var logger := get_node_or_null("/root/TestLogger")
	if logger != null:
		logger.log_event("mission_generated", str({
			"seed": mission_seed,
			"name": planet_name,
			"type": PLANET_TYPE_NAMES[planet_type],
			"size": PLANET_SIZE_NAMES[size_class],
			"gravity": GRAVITY_CLASS_NAMES[gravity_class],
			"props": PROP_PROFILE_NAMES[prop_profile]
		}))

	return current_mission


func get_current_mission() -> Dictionary:
	return current_mission.duplicate(true)


func get_planet_type_name(v: int) -> String:
	return _safe_name(PLANET_TYPE_NAMES, v, "Unknown Planet")


func get_alien_presence_name(v: int) -> String:
	return _safe_name(ALIEN_PRESENCE_NAMES, v, "Unknown Threat")


func get_ore_quantity_name(v: int) -> String:
	return _safe_name(ORE_QUANTITY_NAMES, v, "Unknown Ore")


func get_planet_size_name(v: int) -> String:
	return _safe_name(PLANET_SIZE_NAMES, v, "Unknown Size")


func get_gravity_name(v: int) -> String:
	return _safe_name(GRAVITY_CLASS_NAMES, v, "Unknown Gravity")


func get_prop_profile_name(v: int) -> String:
	return _safe_name(PROP_PROFILE_NAMES, v, "Unknown Props")


func _safe_name(names: PackedStringArray, idx: int, fallback: String) -> String:
	if idx >= 0 and idx < names.size():
		return names[idx]
	return fallback


func _roll_planet_type(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if roll < 0.17:
		return PlanetType.ASTEROID_RUBBLE
	if roll < 0.31:
		return PlanetType.CRATERED_MOON
	if roll < 0.45:
		return PlanetType.METALLIC_CORE
	if roll < 0.58:
		return PlanetType.VOLCANIC_SHARD
	if roll < 0.70:
		return PlanetType.ICE_DUSTBALL
	if roll < 0.82:
		return PlanetType.HABITABLE_WORLD
	if roll < 0.92:
		return PlanetType.DESERT_DUNE
	return PlanetType.TOXIC_SWAMP


func _roll_size_class(rng: RandomNumberGenerator, planet_type: int) -> int:
	if planet_type == PlanetType.HABITABLE_WORLD:
		return _pick_weighted(rng, [PlanetSizeClass.MEDIUM, PlanetSizeClass.LARGE, PlanetSizeClass.HUGE], [0.2, 0.5, 0.3])
	if planet_type == PlanetType.DESERT_DUNE:
		return _pick_weighted(rng, [PlanetSizeClass.SMALL, PlanetSizeClass.MEDIUM, PlanetSizeClass.LARGE], [0.22, 0.5, 0.28])
	if planet_type == PlanetType.TOXIC_SWAMP:
		return _pick_weighted(rng, [PlanetSizeClass.MEDIUM, PlanetSizeClass.LARGE], [0.55, 0.45])
	if planet_type == PlanetType.ASTEROID_RUBBLE:
		return _pick_weighted(rng, [PlanetSizeClass.TINY, PlanetSizeClass.SMALL, PlanetSizeClass.MEDIUM], [0.45, 0.4, 0.15])
	return _pick_weighted(rng, [PlanetSizeClass.SMALL, PlanetSizeClass.MEDIUM, PlanetSizeClass.LARGE], [0.25, 0.55, 0.2])


func _roll_gravity_class(rng: RandomNumberGenerator, planet_type: int, size_class: int) -> int:
	var options: Array[int] = [GravityClass.LOW_G, GravityClass.EARTHLIKE, GravityClass.HEAVY_G]
	var weights: Array[float] = [0.35, 0.45, 0.2]
	if size_class <= PlanetSizeClass.SMALL:
		options = [GravityClass.MICRO_G, GravityClass.LOW_G, GravityClass.EARTHLIKE]
		weights = [0.25, 0.5, 0.25]
	if size_class >= PlanetSizeClass.LARGE:
		options = [GravityClass.LOW_G, GravityClass.EARTHLIKE, GravityClass.HEAVY_G, GravityClass.CRUSHING]
		weights = [0.2, 0.38, 0.28, 0.14]
	if planet_type == PlanetType.METALLIC_CORE:
		options = [GravityClass.EARTHLIKE, GravityClass.HEAVY_G, GravityClass.CRUSHING]
		weights = [0.18, 0.55, 0.27]
	if planet_type == PlanetType.DESERT_DUNE:
		options = [GravityClass.LOW_G, GravityClass.EARTHLIKE, GravityClass.HEAVY_G]
		weights = [0.2, 0.5, 0.3]
	if planet_type == PlanetType.TOXIC_SWAMP:
		options = [GravityClass.EARTHLIKE, GravityClass.HEAVY_G, GravityClass.CRUSHING]
		weights = [0.3, 0.52, 0.18]
	if planet_type == PlanetType.ASTEROID_RUBBLE:
		options = [GravityClass.MICRO_G, GravityClass.LOW_G, GravityClass.EARTHLIKE]
		weights = [0.42, 0.43, 0.15]
	return _pick_weighted(rng, options, weights)


func _roll_ore_quantity(rng: RandomNumberGenerator, planet_type: int) -> int:
	if planet_type == PlanetType.METALLIC_CORE:
		return _pick_weighted(rng, [OreQuantity.STANDARD, OreQuantity.RICH, OreQuantity.BONANZA], [0.25, 0.48, 0.27])
	if planet_type == PlanetType.ICE_DUSTBALL:
		return _pick_weighted(rng, [OreQuantity.SCARCE, OreQuantity.PATCHY, OreQuantity.STANDARD], [0.34, 0.46, 0.2])
	if planet_type == PlanetType.DESERT_DUNE:
		return _pick_weighted(rng, [OreQuantity.PATCHY, OreQuantity.STANDARD, OreQuantity.RICH], [0.4, 0.43, 0.17])
	if planet_type == PlanetType.TOXIC_SWAMP:
		return _pick_weighted(rng, [OreQuantity.STANDARD, OreQuantity.RICH, OreQuantity.BONANZA], [0.3, 0.45, 0.25])
	return _pick_weighted(rng, [OreQuantity.PATCHY, OreQuantity.STANDARD, OreQuantity.RICH], [0.3, 0.45, 0.25])


func _roll_alien_presence(rng: RandomNumberGenerator, planet_type: int) -> int:
	if planet_type == PlanetType.VOLCANIC_SHARD:
		return _pick_weighted(rng, [AlienPresence.MODERATE, AlienPresence.HEAVY, AlienPresence.OVERWHELMING], [0.2, 0.52, 0.28])
	if planet_type == PlanetType.HABITABLE_WORLD:
		return _pick_weighted(rng, [AlienPresence.LOW, AlienPresence.MODERATE, AlienPresence.HEAVY], [0.3, 0.5, 0.2])
	if planet_type == PlanetType.TOXIC_SWAMP:
		return _pick_weighted(rng, [AlienPresence.MODERATE, AlienPresence.HEAVY, AlienPresence.OVERWHELMING], [0.22, 0.5, 0.28])
	return _pick_weighted(rng, [AlienPresence.LOW, AlienPresence.MODERATE, AlienPresence.HEAVY], [0.28, 0.5, 0.22])


func _roll_prop_profile(rng: RandomNumberGenerator, planet_type: int) -> int:
	if planet_type == PlanetType.HABITABLE_WORLD:
		return _pick_weighted(rng, [PropProfile.TREE_GROVES, PropProfile.ANCIENT_RUINS], [0.8, 0.2])
	if planet_type == PlanetType.ICE_DUSTBALL:
		return _pick_weighted(rng, [PropProfile.ICE_SPIKES, PropProfile.BARREN], [0.75, 0.25])
	if planet_type == PlanetType.METALLIC_CORE:
		return _pick_weighted(rng, [PropProfile.CRYSTAL_FIELD, PropProfile.BARREN], [0.7, 0.3])
	if planet_type == PlanetType.VOLCANIC_SHARD:
		return _pick_weighted(rng, [PropProfile.BASALT_COLUMNS, PropProfile.CRYSTAL_FIELD], [0.72, 0.28])
	if planet_type == PlanetType.DESERT_DUNE:
		return _pick_weighted(rng, [PropProfile.ANCIENT_RUINS, PropProfile.BARREN], [0.68, 0.32])
	if planet_type == PlanetType.TOXIC_SWAMP:
		return _pick_weighted(rng, [PropProfile.FUNGAL_BLOOM, PropProfile.ANCIENT_RUINS], [0.78, 0.22])
	return _pick_weighted(rng, [PropProfile.BARREN, PropProfile.CRYSTAL_FIELD, PropProfile.ANCIENT_RUINS], [0.5, 0.32, 0.18])


func _gravity_multiplier_for_class(gravity_class: int) -> float:
	match gravity_class:
		GravityClass.MICRO_G:
			return 0.5
		GravityClass.LOW_G:
			return 0.75
		GravityClass.EARTHLIKE:
			return 1.0
		GravityClass.HEAVY_G:
			return 1.5
		GravityClass.CRUSHING:
			return 2.0
		_:
			return 1.0


func _radius_for_size_class(size_class: int, rng: RandomNumberGenerator) -> float:
	match size_class:
		PlanetSizeClass.TINY:
			return rng.randf_range(230.0, 330.0)
		PlanetSizeClass.SMALL:
			return rng.randf_range(360.0, 560.0)
		PlanetSizeClass.MEDIUM:
			return rng.randf_range(590.0, 820.0)
		PlanetSizeClass.LARGE:
			return rng.randf_range(860.0, 1120.0)
		PlanetSizeClass.HUGE:
			return rng.randf_range(1160.0, 1480.0)
		_:
			return 780.0


func _terrain_profile_for_type(rng: RandomNumberGenerator, planet_type: int) -> Dictionary:
	match planet_type:
		PlanetType.ASTEROID_RUBBLE:
			return {"macro_height": rng.randf_range(38.0, 62.0), "ridge_height": rng.randf_range(15.0, 24.0), "detail_height": rng.randf_range(2.0, 3.2)}
		PlanetType.CRATERED_MOON:
			return {"macro_height": rng.randf_range(24.0, 38.0), "ridge_height": rng.randf_range(8.0, 14.0), "detail_height": rng.randf_range(1.2, 2.1)}
		PlanetType.METALLIC_CORE:
			return {"macro_height": rng.randf_range(20.0, 34.0), "ridge_height": rng.randf_range(6.0, 12.0), "detail_height": rng.randf_range(0.8, 1.5)}
		PlanetType.VOLCANIC_SHARD:
			return {"macro_height": rng.randf_range(45.0, 68.0), "ridge_height": rng.randf_range(14.0, 24.0), "detail_height": rng.randf_range(1.4, 2.4)}
		PlanetType.ICE_DUSTBALL:
			return {"macro_height": rng.randf_range(14.0, 25.0), "ridge_height": rng.randf_range(5.0, 10.0), "detail_height": rng.randf_range(0.6, 1.2)}
		PlanetType.HABITABLE_WORLD:
			return {"macro_height": rng.randf_range(18.0, 30.0), "ridge_height": rng.randf_range(6.0, 11.0), "detail_height": rng.randf_range(0.7, 1.4)}
		PlanetType.DESERT_DUNE:
			return {"macro_height": rng.randf_range(16.0, 26.0), "ridge_height": rng.randf_range(3.0, 8.0), "detail_height": rng.randf_range(0.4, 0.9)}
		PlanetType.TOXIC_SWAMP:
			return {"macro_height": rng.randf_range(22.0, 36.0), "ridge_height": rng.randf_range(7.0, 13.0), "detail_height": rng.randf_range(1.6, 2.7)}
		_:
			return {"macro_height": 28.0, "ridge_height": 9.0, "detail_height": 1.2}


func _ore_count_for_quantity(ore_quantity: int, size_class: int, rng: RandomNumberGenerator) -> int:
	var base: int = 52 + size_class * 20
	match ore_quantity:
		OreQuantity.SCARCE:
			base -= 16
		OreQuantity.PATCHY:
			base -= 6
		OreQuantity.STANDARD:
			base += 0
		OreQuantity.RICH:
			base += 20
		OreQuantity.BONANZA:
			base += 36
	return maxi(24, base + rng.randi_range(-10, 12))


func _alien_budget_for_presence(alien_presence: int, size_class: int, rng: RandomNumberGenerator) -> int:
	var base: int = 2 + size_class
	match alien_presence:
		AlienPresence.NONE:
			base = 0
		AlienPresence.LOW:
			base += 2
		AlienPresence.MODERATE:
			base += 5
		AlienPresence.HEAVY:
			base += 9
		AlienPresence.OVERWHELMING:
			base += 13
	return maxi(0, base + rng.randi_range(-1, 2))


func _alien_interval_for_presence(alien_presence: int, rng: RandomNumberGenerator) -> float:
	match alien_presence:
		AlienPresence.NONE:
			return 9999.0
		AlienPresence.LOW:
			return rng.randf_range(14.0, 20.0)
		AlienPresence.MODERATE:
			return rng.randf_range(9.0, 13.0)
		AlienPresence.HEAVY:
			return rng.randf_range(6.0, 9.0)
		AlienPresence.OVERWHELMING:
			return rng.randf_range(4.0, 6.0)
		_:
			return 12.0


func _prop_density_for_profile(prop_profile: int, size_class: int, rng: RandomNumberGenerator) -> float:
	var size_factor: float = 0.7 + 0.15 * float(size_class)
	match prop_profile:
		PropProfile.BARREN:
			return rng.randf_range(0.005, 0.015) * size_factor
		PropProfile.CRYSTAL_FIELD:
			return rng.randf_range(0.02, 0.045) * size_factor
		PropProfile.ANCIENT_RUINS:
			return rng.randf_range(0.012, 0.028) * size_factor
		PropProfile.TREE_GROVES:
			return rng.randf_range(0.04, 0.085) * size_factor
		PropProfile.ICE_SPIKES:
			return rng.randf_range(0.018, 0.04) * size_factor
		PropProfile.BASALT_COLUMNS:
			return rng.randf_range(0.015, 0.032) * size_factor
		PropProfile.FUNGAL_BLOOM:
			return rng.randf_range(0.03, 0.07) * size_factor
		_:
			return 0.01


func _compute_yelp(ore_quantity: int, alien_presence: int, gravity_class: int, planet_type: int, rng: RandomNumberGenerator) -> Dictionary:
	var score: float = 2.5
	score += (float(ore_quantity) - 2.0) * 0.5
	score -= (float(alien_presence) - 1.5) * 0.35
	score -= maxf(0.0, float(gravity_class) - 2.0) * 0.2
	if planet_type == PlanetType.HABITABLE_WORLD:
		score += 0.35
	if planet_type == PlanetType.DESERT_DUNE:
		score += 0.08
	if planet_type == PlanetType.TOXIC_SWAMP:
		score -= 0.22
	score += rng.randf_range(-0.2, 0.2)
	score = clampf(score, 1.0, 5.0)

	var tagline: String = "Rocky but scenic"
	if score >= 4.2:
		tagline = "Would drill here again."
	elif score >= 3.4:
		tagline = "Solid views, manageable danger."
	elif score >= 2.6:
		tagline = "Bring spare tires."
	elif score >= 1.8:
		tagline = "Hazard pay required."
	else:
		tagline = "One star. Aliens ate my suspension."
	return {"score": score, "tagline": tagline}


func _generate_planet_name(rng: RandomNumberGenerator, planet_type: int) -> String:
	var prefixes: PackedStringArray = ["LV", "RX", "K2", "TQ", "MN", "Argo", "Nexus", "Caldera", "Drift", "Hollow"]
	var suffixes: PackedStringArray = ["-7", "-12", "-IX", "-Prime", "-B", "-Outpost", "-Reach", "-Delta"]
	var base: String = "%s%s" % [prefixes[rng.randi_range(0, prefixes.size() - 1)], suffixes[rng.randi_range(0, suffixes.size() - 1)]]
	match planet_type:
		PlanetType.HABITABLE_WORLD:
			return "%s Verdant" % base
		PlanetType.VOLCANIC_SHARD:
			return "%s Ember" % base
		PlanetType.ICE_DUSTBALL:
			return "%s Frost" % base
		PlanetType.METALLIC_CORE:
			return "%s Ferrum" % base
		PlanetType.DESERT_DUNE:
			return "%s Dune" % base
		PlanetType.TOXIC_SWAMP:
			return "%s Mire" % base
		_:
			return base


func _pick_weighted(rng: RandomNumberGenerator, options: Array, weights: Array) -> int:
	if options.is_empty():
		return 0
	var total: float = 0.0
	for w in weights:
		total += float(w)
	var roll: float = rng.randf_range(0.0, total)
	var acc: float = 0.0
	for i in range(options.size()):
		acc += float(weights[i])
		if roll <= acc:
			return int(options[i])
	return int(options[options.size() - 1])
