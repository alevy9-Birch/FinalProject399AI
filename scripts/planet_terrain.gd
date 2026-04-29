extends StaticBody3D

## Procedural sphere with layered noise displacement (hills / mountains).
## Builds mesh + concave trimesh collision once on ready.

const ORE_DEPOSIT_SCRIPT := preload("res://scripts/ore_deposit.gd")
const WORLD_CHECKER_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 color_a : source_color = vec4(0.98, 0.98, 0.98, 1.0);
uniform vec4 color_b : source_color = vec4(0.04, 0.04, 0.04, 1.0);
uniform vec4 line_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float tile_world_size = 220.0;
uniform float line_width = 0.04;
uniform float triplanar_sharpness = 6.0;
uniform float roughness_value = 0.86;

vec2 world_plane_uv(vec3 wp, int axis) {
	if (axis == 0) {
		return wp.zy / tile_world_size;
	}
	if (axis == 1) {
		return wp.xz / tile_world_size;
	}
	return wp.xy / tile_world_size;
}

float checker(vec2 uv) {
	vec2 g = floor(uv);
	return mod(g.x + g.y, 2.0);
}

float grid_line(vec2 uv) {
	vec2 f = fract(uv);
	vec2 dist = min(f, 1.0 - f);
	float min_dist = min(dist.x, dist.y);
	return 1.0 - smoothstep(0.0, line_width, min_dist);
}

void fragment() {
	vec3 n = normalize(abs(NORMAL));
	vec3 weights = pow(n, vec3(triplanar_sharpness));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);

	vec3 wp = WORLD_POSITION;
	vec2 uv_x = world_plane_uv(wp, 0);
	vec2 uv_y = world_plane_uv(wp, 1);
	vec2 uv_z = world_plane_uv(wp, 2);

	float c_x = checker(uv_x);
	float c_y = checker(uv_y);
	float c_z = checker(uv_z);
	float checker_mix = c_x * weights.x + c_y * weights.y + c_z * weights.z;

	float l_x = grid_line(uv_x);
	float l_y = grid_line(uv_y);
	float l_z = grid_line(uv_z);
	float line_mix = l_x * weights.x + l_y * weights.y + l_z * weights.z;

	vec3 base = mix(color_a.rgb, color_b.rgb, checker_mix);
	ALBEDO = mix(base, line_color.rgb, clamp(line_mix, 0.0, 1.0));
	ROUGHNESS = roughness_value;
}
"""
const PROP_PREFABS: Dictionary = {
	"rock_cluster": preload("res://scenes/props/RockCluster.tscn"),
	"crater_decal": preload("res://scenes/props/CraterDecal.tscn"),
	"salvage_heap": preload("res://scenes/props/SalvageHeap.tscn"),
	"crystal": preload("res://scenes/props/Crystal.tscn"),
	"ruin_pillar": preload("res://scenes/props/RuinPillar.tscn"),
	"tree": preload("res://scenes/props/Tree.tscn"),
	"ice_spike": preload("res://scenes/props/IceSpike.tscn"),
	"basalt_column": preload("res://scenes/props/BasaltColumn.tscn"),
	"fungal_bloom": preload("res://scenes/props/FungalBloom.tscn"),
	"metal_spire": preload("res://scenes/props/MetalSpire.tscn"),
	"lava_vent": preload("res://scenes/props/LavaVent.tscn"),
	"dune_grass": preload("res://scenes/props/DuneGrass.tscn"),
	"toxic_pod": preload("res://scenes/props/ToxicPod.tscn")
}

@export var planet_radius: float = 980.0
@export var rings: int = 64
@export var radial_segments: int = 128
@export var macro_height: float = 40.0
@export var ridge_height: float = 10.0
@export var detail_height: float = 1.2
@export var noise_macro_scale: float = 1.9
@export var noise_ridge_scale: float = 5.6
@export var noise_detail_scale: float = 16.0
@export var rover_spawn_surface_offset: float = 62.0
@export var enemy_spawn_surface_offset: float = 32.0
@export var ground_spawn_surface_offset: float = 0.6

@onready var _mesh_instance: MeshInstance3D = $PlanetMesh
@onready var _collision_shape: CollisionShape3D = $PlanetCollision
@onready var _props_root: Node3D = _ensure_props_root()
@onready var _ore_root: Node3D = _ensure_ore_root()


func _ready() -> void:
	var mission := _get_mission_data()
	_apply_mission_params(mission)
	var mission_seed: int = int(mission.get("mission_seed", 1))

	var macro: FastNoiseLite = FastNoiseLite.new()
	macro.seed = mission_seed + 101
	macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro.frequency = 0.55
	macro.fractal_octaves = 4
	macro.fractal_lacunarity = 2.05
	macro.fractal_gain = 0.48

	var ridge: FastNoiseLite = FastNoiseLite.new()
	ridge.seed = mission_seed + 202
	ridge.noise_type = FastNoiseLite.TYPE_PERLIN
	ridge.frequency = 0.9
	ridge.fractal_octaves = 3
	ridge.fractal_lacunarity = 2.2
	ridge.fractal_gain = 0.55

	var detail: FastNoiseLite = FastNoiseLite.new()
	detail.seed = mission_seed + 303
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 1.0
	detail.fractal_octaves = 2

	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	var ring_count: int = maxi(rings, 16)
	var seg_count: int = maxi(radial_segments, 32)

	for ring_i in range(ring_count + 1):
		var v: float = float(ring_i) / float(ring_count)
		var theta: float = PI * v
		var sin_t: float = sin(theta)
		var cos_t: float = cos(theta)
		for seg_i in range(seg_count + 1):
			var u: float = float(seg_i) / float(seg_count)
			var phi: float = TAU * u
			var dir: Vector3 = Vector3(sin_t * cos(phi), cos_t, sin_t * sin(phi))
			var mpos: Vector3 = dir * noise_macro_scale
			var n_macro: float = macro.get_noise_3d(mpos.x, mpos.y, mpos.z)
			var rpos: Vector3 = dir * noise_ridge_scale
			var n_ridge: float = absf(ridge.get_noise_3d(rpos.x, rpos.y, rpos.z))
			var dpos: Vector3 = dir * noise_detail_scale
			var n_detail: float = detail.get_noise_3d(dpos.x, dpos.y, dpos.z)
			var disp: float = n_macro * macro_height + n_ridge * ridge_height + n_detail * detail_height
			disp *= 0.85 + 0.15 * smoothstep(0.0, 1.0, clampf((n_macro + 1.0) * 0.5, 0.0, 1.0))
			var p: Vector3 = dir * (planet_radius + disp)
			verts.append(p)
			uvs.append(Vector2(u, v))

	for ring_i in range(ring_count):
		for seg_i in range(seg_count):
			var a: int = ring_i * (seg_count + 1) + seg_i
			var b: int = a + seg_count + 1
			var c: int = b + 1
			var d: int = a + 1
			indices.append_array([a, b, c, a, c, d])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_mesh_instance.mesh = arr_mesh
	_apply_surface_material(mission)

	var trimesh: Shape3D = arr_mesh.create_trimesh_shape()
	if trimesh != null:
		_collision_shape.shape = trimesh

	_spawn_props(mission, macro, ridge, detail)
	_spawn_ore_deposits(mission, macro, ridge, detail)
	_position_rover_spawn(mission, macro, ridge, detail)


func _get_mission_data() -> Dictionary:
	var mission_generator := get_node_or_null("/root/MissionGenerator")
	if mission_generator == null:
		return {}
	var mission: Dictionary = mission_generator.get_current_mission()
	if mission.is_empty():
		mission = mission_generator.generate_new_mission()
	return mission


func _apply_mission_params(mission: Dictionary) -> void:
	if mission.is_empty():
		return
	planet_radius = float(mission.get("planet_radius", planet_radius))
	var terrain: Dictionary = mission.get("terrain_profile", {}) as Dictionary
	if not terrain.is_empty():
		macro_height = float(terrain.get("macro_height", macro_height))
		ridge_height = float(terrain.get("ridge_height", ridge_height))
		detail_height = float(terrain.get("detail_height", detail_height))

	var size_class: int = int(mission.get("planet_size_class", 2))
	match size_class:
		0:
			rings = 40
			radial_segments = 80
		1:
			rings = 50
			radial_segments = 96
		2:
			rings = 64
			radial_segments = 128
		3:
			rings = 76
			radial_segments = 152
		4:
			rings = 86
			radial_segments = 176


func _ensure_props_root() -> Node3D:
	var existing: Node = get_node_or_null("PropsRoot")
	if existing is Node3D:
		return existing as Node3D
	var root := Node3D.new()
	root.name = "PropsRoot"
	add_child(root)
	return root


func _clear_existing_props() -> void:
	for child in _props_root.get_children():
		child.queue_free()


func _ensure_ore_root() -> Node3D:
	var existing: Node = get_node_or_null("OreRoot")
	if existing is Node3D:
		return existing as Node3D
	var root := Node3D.new()
	root.name = "OreRoot"
	add_child(root)
	return root


func _clear_existing_ore() -> void:
	for child in _ore_root.get_children():
		child.queue_free()


func _sample_displacement(dir: Vector3, macro: FastNoiseLite, ridge: FastNoiseLite, detail: FastNoiseLite) -> float:
	var mpos: Vector3 = dir * noise_macro_scale
	var n_macro: float = macro.get_noise_3d(mpos.x, mpos.y, mpos.z)
	var rpos: Vector3 = dir * noise_ridge_scale
	var n_ridge: float = absf(ridge.get_noise_3d(rpos.x, rpos.y, rpos.z))
	var dpos: Vector3 = dir * noise_detail_scale
	var n_detail: float = detail.get_noise_3d(dpos.x, dpos.y, dpos.z)
	var disp: float = n_macro * macro_height + n_ridge * ridge_height + n_detail * detail_height
	disp *= 0.85 + 0.15 * smoothstep(0.0, 1.0, clampf((n_macro + 1.0) * 0.5, 0.0, 1.0))
	return disp


func _sample_surface_point(dir: Vector3, macro: FastNoiseLite, ridge: FastNoiseLite, detail: FastNoiseLite) -> Vector3:
	var disp: float = _sample_displacement(dir, macro, ridge, detail)
	return dir * (planet_radius + disp)


func get_surface_spawn_from_direction(dir: Vector3, cast_extra: float = 220.0, spawn_offset: float = 0.0, exclude: Array = []) -> Dictionary:
	var d: Vector3 = dir.normalized()
	if d.length_squared() < 0.0001:
		d = Vector3.UP
	var terrain_span: float = maxf(120.0, macro_height + ridge_height + detail_height + 80.0)
	var cast_extent: float = maxf(planet_radius + terrain_span + cast_extra, 260.0)
	var start: Vector3 = global_position + d * cast_extent
	var end: Vector3 = global_position - d * cast_extent
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = exclude
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {
			"ok": false,
			"point": global_position + d * planet_radius,
			"normal": d
		}
	var hit_pos: Vector3 = hit["position"] as Vector3
	var radial_up: Vector3 = (hit_pos - global_position).normalized()
	var normal: Vector3 = (hit["normal"] as Vector3).normalized()
	# Concave trimesh normals can occasionally point inward; force outward so offsets never push into terrain.
	if normal.dot(radial_up) < 0.0:
		normal = -normal
	var point: Vector3 = hit_pos + normal * spawn_offset
	return {
		"ok": true,
		"point": point,
		"normal": normal
	}


func _spawn_props(mission: Dictionary, macro: FastNoiseLite, ridge: FastNoiseLite, detail: FastNoiseLite) -> void:
	_clear_existing_props()
	if mission.is_empty():
		return

	var mission_seed: int = int(mission.get("mission_seed", 1))
	var prop_density: float = float(mission.get("prop_density", 0.01))
	var planet_type: int = int(mission.get("planet_type", 0))
	var prop_profile: int = int(mission.get("prop_profile", 0))
	var prop_count: int = clampi(int(1200.0 * prop_density), 4, 140)
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed + 404
	var prop_pool: Dictionary = _build_prop_pool_for_planet(planet_type, prop_profile)
	var prop_kinds: PackedStringArray = prop_pool.get("kinds", PackedStringArray(["rock_cluster"]))
	var prop_weights: Array[float] = prop_pool.get("weights", [1.0])

	for i in range(prop_count):
		var dir := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		if dir.length_squared() < 0.001:
			continue
		var spawn_info: Dictionary = get_surface_spawn_from_direction(dir, 180.0, ground_spawn_surface_offset)
		var kind: String = _pick_weighted_name(rng, prop_kinds, prop_weights)
		var prop := _build_prop_by_name(kind, rng)
		if prop == null:
			continue
		prop.global_position = spawn_info.get("point", global_position + dir * planet_radius)
		var normal: Vector3 = spawn_info.get("normal", dir)
		var tangent_ref: Vector3 = Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
		prop.basis = Basis.looking_at((normal.cross(tangent_ref)).normalized(), normal)
		prop.rotate_object_local(Vector3.UP, rng.randf_range(-PI, PI))
		_props_root.add_child(prop)


func _spawn_ore_deposits(mission: Dictionary, macro: FastNoiseLite, ridge: FastNoiseLite, detail: FastNoiseLite) -> void:
	_clear_existing_ore()
	if mission.is_empty():
		return
	var mission_seed: int = int(mission.get("mission_seed", 1))
	var ore_count: int = int(mission.get("ore_node_count", 0))
	var yield_range: Vector2i = mission.get("ore_yield_range", Vector2i(1, 3)) as Vector2i
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed + 505

	for i in range(maxi(0, ore_count)):
		var dir := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		if dir.length_squared() < 0.001:
			continue
		var spawn_info: Dictionary = get_surface_spawn_from_direction(dir, 170.0, ground_spawn_surface_offset)
		var ore := Node3D.new()
		ore.name = "OreDeposit_%d" % i
		ore.set_script(ORE_DEPOSIT_SCRIPT)
		ore.set("ore_value", rng.randi_range(yield_range.x, max(yield_range.x, yield_range.y)))
		ore.global_position = spawn_info.get("point", global_position + dir * planet_radius)
		var ore_normal: Vector3 = spawn_info.get("normal", dir)
		var ore_tangent_ref: Vector3 = Vector3.RIGHT if absf(ore_normal.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
		ore.basis = Basis.looking_at((ore_normal.cross(ore_tangent_ref)).normalized(), ore_normal)
		ore.add_to_group("ore_deposit")
		ore.add_child(_make_ore_visual(rng))
		_ore_root.add_child(ore)


func _make_ore_visual(rng: RandomNumberGenerator) -> MeshInstance3D:
	var ore_mesh := MeshInstance3D.new()
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.03
	crystal.bottom_radius = rng.randf_range(0.12, 0.18)
	crystal.height = rng.randf_range(0.8, 1.6)
	crystal.radial_segments = 6
	ore_mesh.mesh = crystal
	ore_mesh.position = Vector3(0, crystal.height * 0.5 + 0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.84, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.72, 0.1, 1.0)
	mat.emission_energy_multiplier = 0.8
	mat.roughness = 0.18
	ore_mesh.material_override = mat
	return ore_mesh


func _build_prop(prop_profile: int, rng: RandomNumberGenerator) -> Node3D:
	match prop_profile:
		0:
			return _make_rock_cluster(rng)
		1:
			return _make_crystal(rng)
		2:
			return _make_ruin_pillar(rng)
		3:
			return _make_tree(rng)
		4:
			return _make_ice_spike(rng)
		5:
			return _make_basalt_column(rng)
		6:
			return _make_fungal_bloom(rng)
		_:
			return _make_rock_cluster(rng)


func _build_prop_pool_for_planet(planet_type: int, prop_profile: int) -> Dictionary:
	match planet_type:
		0:
			return {"kinds": PackedStringArray(["rock_cluster", "crater_decal", "salvage_heap"]), "weights": [0.55, 0.25, 0.2]}
		1:
			return {"kinds": PackedStringArray(["crater_decal", "rock_cluster", "ruin_pillar"]), "weights": [0.45, 0.35, 0.2]}
		2:
			return {"kinds": PackedStringArray(["metal_spire", "crystal", "salvage_heap"]), "weights": [0.45, 0.35, 0.2]}
		3:
			return {"kinds": PackedStringArray(["basalt_column", "lava_vent", "crystal"]), "weights": [0.5, 0.35, 0.15]}
		4:
			return {"kinds": PackedStringArray(["ice_spike", "crystal", "rock_cluster"]), "weights": [0.58, 0.27, 0.15]}
		5:
			return {"kinds": PackedStringArray(["tree", "ruin_pillar", "rock_cluster"]), "weights": [0.62, 0.2, 0.18]}
		6:
			return {"kinds": PackedStringArray(["dune_grass", "ruin_pillar", "rock_cluster"]), "weights": [0.55, 0.25, 0.2]}
		7:
			return {"kinds": PackedStringArray(["fungal_bloom", "toxic_pod", "ruin_pillar"]), "weights": [0.56, 0.28, 0.16]}
		_:
			match prop_profile:
				1:
					return {"kinds": PackedStringArray(["crystal", "rock_cluster"]), "weights": [0.7, 0.3]}
				2:
					return {"kinds": PackedStringArray(["ruin_pillar", "rock_cluster"]), "weights": [0.6, 0.4]}
				3:
					return {"kinds": PackedStringArray(["tree", "rock_cluster"]), "weights": [0.72, 0.28]}
				4:
					return {"kinds": PackedStringArray(["ice_spike", "rock_cluster"]), "weights": [0.68, 0.32]}
				5:
					return {"kinds": PackedStringArray(["basalt_column", "rock_cluster"]), "weights": [0.68, 0.32]}
				6:
					return {"kinds": PackedStringArray(["fungal_bloom", "ruin_pillar"]), "weights": [0.8, 0.2]}
				_:
					return {"kinds": PackedStringArray(["rock_cluster"]), "weights": [1.0]}


func _pick_weighted_name(rng: RandomNumberGenerator, names: PackedStringArray, weights: Array[float]) -> String:
	if names.is_empty():
		return "rock_cluster"
	if names.size() == 1 or names.size() != weights.size():
		return names[0]
	var total: float = 0.0
	for w in weights:
		total += maxf(0.001, float(w))
	var roll: float = rng.randf_range(0.0, total)
	var acc: float = 0.0
	for i in range(names.size()):
		acc += maxf(0.001, float(weights[i]))
		if roll <= acc:
			return names[i]
	return names[names.size() - 1]


func _build_prop_by_name(kind: String, rng: RandomNumberGenerator) -> Node3D:
	var from_prefab: Node3D = _instantiate_prop_prefab(kind, rng)
	if from_prefab != null:
		return from_prefab
	match kind:
		"rock_cluster":
			return _make_rock_cluster(rng)
		"crystal":
			return _make_crystal(rng)
		"ruin_pillar":
			return _make_ruin_pillar(rng)
		"tree":
			return _make_tree(rng)
		"ice_spike":
			return _make_ice_spike(rng)
		"basalt_column":
			return _make_basalt_column(rng)
		"fungal_bloom":
			return _make_fungal_bloom(rng)
		"crater_decal":
			return _make_crater_decal(rng)
		"salvage_heap":
			return _make_salvage_heap(rng)
		"metal_spire":
			return _make_metal_spire(rng)
		"lava_vent":
			return _make_lava_vent(rng)
		"dune_grass":
			return _make_dune_grass(rng)
		"toxic_pod":
			return _make_toxic_pod(rng)
		_:
			return _make_rock_cluster(rng)


func _instantiate_prop_prefab(kind: String, rng: RandomNumberGenerator) -> Node3D:
	var packed: PackedScene = PROP_PREFABS.get(kind, null) as PackedScene
	if packed == null:
		return null
	var node: Node = packed.instantiate()
	if not (node is Node3D):
		return null
	var prop: Node3D = node as Node3D
	var scale_jitter: float = rng.randf_range(0.82, 1.24)
	prop.scale = Vector3.ONE * scale_jitter
	return prop


func _make_rock_cluster(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	for i in range(rng.randi_range(1, 3)):
		var mesh := MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		mesh.scale = Vector3.ONE * rng.randf_range(0.6, 1.8)
		mesh.position = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 0.9), rng.randf_range(-0.6, 0.6))
		mesh.material_override = _make_prop_material(Color(0.36, 0.33, 0.3, 1.0), 0.96, 0.0)
		root.add_child(mesh)
	return root


func _make_crystal(rng: RandomNumberGenerator) -> Node3D:
	var mesh := MeshInstance3D.new()
	var prism := CylinderMesh.new()
	prism.top_radius = 0.08
	prism.bottom_radius = rng.randf_range(0.18, 0.26)
	prism.height = rng.randf_range(1.6, 3.8)
	prism.radial_segments = 6
	mesh.mesh = prism
	mesh.position = Vector3(0, prism.height * 0.5, 0)
	mesh.material_override = _make_prop_material(Color(0.42, 0.8, 0.92, 1.0), 0.1, 0.65)
	return mesh


func _make_ruin_pillar(rng: RandomNumberGenerator) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(rng.randf_range(0.35, 0.7), rng.randf_range(1.0, 2.4), rng.randf_range(0.35, 0.7))
	mesh.mesh = box
	mesh.position = Vector3(0, box.size.y * 0.5, 0)
	mesh.material_override = _make_prop_material(Color(0.5, 0.46, 0.4, 1.0), 0.82, 0.0)
	return mesh


func _make_tree(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = rng.randf_range(1.4, 2.8)
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0, trunk_mesh.height * 0.5, 0)
	trunk.material_override = _make_prop_material(Color(0.42, 0.28, 0.2, 1.0), 0.9, 0.0)
	root.add_child(trunk)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = rng.randf_range(0.65, 1.25)
	canopy_mesh.height = canopy_mesh.radius * 2.0
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0, trunk_mesh.height + canopy_mesh.radius * 0.7, 0)
	canopy.material_override = _make_prop_material(Color(0.25, 0.58, 0.3, 1.0), 0.88, 0.0)
	root.add_child(canopy)
	return root


func _make_ice_spike(rng: RandomNumberGenerator) -> Node3D:
	var mesh := MeshInstance3D.new()
	var spike := CylinderMesh.new()
	spike.top_radius = 0.02
	spike.bottom_radius = rng.randf_range(0.12, 0.2)
	spike.height = rng.randf_range(1.8, 3.2)
	spike.radial_segments = 8
	mesh.mesh = spike
	mesh.position = Vector3(0, spike.height * 0.5, 0)
	mesh.material_override = _make_prop_material(Color(0.75, 0.9, 0.98, 1.0), 0.08, 0.35)
	return mesh


func _make_basalt_column(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var count: int = rng.randi_range(2, 4)
	for i in range(count):
		var col := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = rng.randf_range(0.08, 0.16)
		mesh.bottom_radius = mesh.top_radius * rng.randf_range(1.05, 1.22)
		mesh.height = rng.randf_range(1.2, 3.6)
		mesh.radial_segments = 6
		col.mesh = mesh
		col.position = Vector3(rng.randf_range(-0.35, 0.35), mesh.height * 0.5, rng.randf_range(-0.35, 0.35))
		col.material_override = _make_prop_material(Color(0.18, 0.18, 0.2, 1.0), 0.95, 0.05)
		root.add_child(col)
	return root


func _make_fungal_bloom(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var stalk := MeshInstance3D.new()
	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = 0.09
	stalk_mesh.bottom_radius = 0.12
	stalk_mesh.height = rng.randf_range(0.9, 1.8)
	stalk.mesh = stalk_mesh
	stalk.position = Vector3(0, stalk_mesh.height * 0.5, 0)
	stalk.material_override = _make_prop_material(Color(0.22, 0.6, 0.36, 1.0), 0.72, 0.0)
	root.add_child(stalk)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = rng.randf_range(0.35, 0.7)
	cap_mesh.height = cap_mesh.radius * 1.2
	cap.mesh = cap_mesh
	cap.position = Vector3(0, stalk_mesh.height + cap_mesh.height * 0.3, 0)
	var cap_color := Color(0.4, 0.9, 0.48, 1.0) if rng.randf() < 0.5 else Color(0.8, 0.28, 0.86, 1.0)
	var cap_mat := _make_prop_material(cap_color, 0.25, 0.05)
	cap_mat.emission_enabled = true
	cap_mat.emission = cap_color * 0.35
	cap_mat.emission_energy_multiplier = 0.55
	cap.material_override = cap_mat
	root.add_child(cap)
	return root


func _make_crater_decal(rng: RandomNumberGenerator) -> Node3D:
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = rng.randf_range(1.8, 3.4)
	disc.bottom_radius = disc.top_radius * rng.randf_range(1.05, 1.2)
	disc.height = 0.08
	mesh.mesh = disc
	mesh.position = Vector3(0, 0.04, 0)
	mesh.material_override = _make_prop_material(Color(0.26, 0.24, 0.24, 1.0), 1.0, 0.0)
	return mesh


func _make_salvage_heap(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var count: int = rng.randi_range(2, 5)
	for i in range(count):
		var bit := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.2, 0.9), rng.randf_range(0.14, 0.5), rng.randf_range(0.2, 0.9))
		bit.mesh = b
		bit.position = Vector3(rng.randf_range(-0.7, 0.7), b.size.y * 0.5, rng.randf_range(-0.7, 0.7))
		bit.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-PI, PI), rng.randf_range(-0.3, 0.3))
		bit.material_override = _make_prop_material(Color(0.44, 0.44, 0.46, 1.0), 0.55, 0.45)
		root.add_child(bit)
	return root


func _make_metal_spire(rng: RandomNumberGenerator) -> Node3D:
	var mesh := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.03
	c.bottom_radius = rng.randf_range(0.14, 0.24)
	c.height = rng.randf_range(2.2, 4.8)
	c.radial_segments = 5
	mesh.mesh = c
	mesh.position = Vector3(0, c.height * 0.5, 0)
	mesh.material_override = _make_prop_material(Color(0.56, 0.6, 0.64, 1.0), 0.28, 0.8)
	return mesh


func _make_lava_vent(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var cone := MeshInstance3D.new()
	var vent := CylinderMesh.new()
	vent.top_radius = rng.randf_range(0.12, 0.2)
	vent.bottom_radius = rng.randf_range(0.5, 0.9)
	vent.height = rng.randf_range(0.35, 0.7)
	vent.radial_segments = 8
	cone.mesh = vent
	cone.position = Vector3(0, vent.height * 0.5, 0)
	cone.material_override = _make_prop_material(Color(0.22, 0.16, 0.14, 1.0), 0.92, 0.08)
	root.add_child(cone)
	var glow := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = rng.randf_range(0.12, 0.24)
	orb.height = orb.radius * 2.0
	glow.mesh = orb
	glow.position = Vector3(0, vent.height * 0.58, 0)
	var mat := _make_prop_material(Color(0.95, 0.42, 0.14, 1.0), 0.2, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.08, 1.0)
	mat.emission_energy_multiplier = 1.35
	glow.material_override = mat
	root.add_child(glow)
	return root


func _make_dune_grass(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var blade_count: int = rng.randi_range(3, 6)
	for i in range(blade_count):
		var blade := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.04, 0.08), rng.randf_range(0.35, 0.8), rng.randf_range(0.02, 0.05))
		blade.mesh = b
		blade.position = Vector3(rng.randf_range(-0.22, 0.22), b.size.y * 0.5, rng.randf_range(-0.22, 0.22))
		blade.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-PI, PI), rng.randf_range(-0.12, 0.12))
		blade.material_override = _make_prop_material(Color(0.68, 0.6, 0.28, 1.0), 0.88, 0.0)
		root.add_child(blade)
	return root


func _make_toxic_pod(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var pod := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rng.randf_range(0.24, 0.45)
	s.height = s.radius * 2.0
	pod.mesh = s
	pod.position = Vector3(0, s.radius, 0)
	var pod_mat := _make_prop_material(Color(0.35, 0.78, 0.26, 1.0), 0.25, 0.0)
	pod_mat.emission_enabled = true
	pod_mat.emission = Color(0.24, 0.95, 0.2, 1.0)
	pod_mat.emission_energy_multiplier = 0.75
	pod.material_override = pod_mat
	root.add_child(pod)
	return root


func _make_prop_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _apply_surface_material(mission: Dictionary) -> void:
	var shader_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WORLD_CHECKER_SHADER
	shader_material.shader = shader
	var planet_type: int = int(mission.get("planet_type", 0))
	var mission_seed: int = int(mission.get("mission_seed", 1))
	var roughness_value: float = 0.88
	var tile_world_size: float = 220.0
	var line_color: Color = Color(1.0, 0.22, 0.22, 1.0)
	var base_a: Color = Color(0.98, 0.98, 0.98, 1.0)
	var base_b: Color = Color(0.04, 0.04, 0.04, 1.0)
	match planet_type:
		0:
			line_color = Color(0.9, 0.66, 0.22, 1.0)
			tile_world_size = 230.0
		1:
			line_color = Color(0.62, 0.75, 1.0, 1.0)
			tile_world_size = 215.0
		2:
			line_color = Color(0.62, 1.0, 1.0, 1.0)
			tile_world_size = 245.0
			roughness_value = 0.72
		3:
			line_color = Color(1.0, 0.45, 0.12, 1.0)
			tile_world_size = 205.0
		4:
			line_color = Color(0.58, 0.85, 1.0, 1.0)
			tile_world_size = 260.0
		5:
			line_color = Color(0.45, 0.95, 0.42, 1.0)
			tile_world_size = 220.0
		6:
			line_color = Color(0.96, 0.82, 0.25, 1.0)
			tile_world_size = 210.0
		7:
			line_color = Color(0.45, 1.0, 0.35, 1.0)
			tile_world_size = 200.0
	var jitter := (float((mission_seed % 13) - 6)) * 0.004
	base_a = base_a.lightened(jitter)
	base_b = base_b.lightened(-jitter * 0.5)
	shader_material.set_shader_parameter("color_a", base_a)
	shader_material.set_shader_parameter("color_b", base_b)
	shader_material.set_shader_parameter("line_color", line_color)
	shader_material.set_shader_parameter("tile_world_size", tile_world_size)
	shader_material.set_shader_parameter("roughness_value", roughness_value)
	_mesh_instance.material_override = shader_material


func _position_rover_spawn(mission: Dictionary, macro: FastNoiseLite, ridge: FastNoiseLite, detail: FastNoiseLite) -> void:
	var rover: Node3D = get_node_or_null("../Rover") as Node3D
	if rover == null:
		return
	var up := Vector3.UP
	var spawn_info: Dictionary = get_surface_spawn_from_direction(up, 260.0, rover_spawn_surface_offset, [rover])
	var min_clearance: float = _estimate_body_clearance(rover)
	var base_offset: float = maxf(rover_spawn_surface_offset, min_clearance)
	if min_clearance > rover_spawn_surface_offset:
		spawn_info = get_surface_spawn_from_direction(up, 300.0, base_offset, [rover])
	var surface_point: Vector3 = spawn_info.get("point", global_position + up * (planet_radius + base_offset))
	var surface_up: Vector3 = spawn_info.get("normal", up)
	rover.global_position = surface_point
	if rover is RigidBody3D:
		var rb: RigidBody3D = rover as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD.slide(surface_up).normalized()
	if forward.length_squared() < 0.001:
		forward = surface_up.cross(Vector3.RIGHT).normalized()
	rover.global_basis = Basis.looking_at(forward, surface_up, true).orthonormalized()
	var powerup: Area3D = get_node_or_null("../JetpackPowerup") as Area3D
	if powerup != null:
		var tangent: Vector3 = surface_up.cross(Vector3.RIGHT)
		if tangent.length_squared() < 0.01:
			tangent = surface_up.cross(Vector3.FORWARD)
		tangent = tangent.normalized()
		var powerup_dir: Vector3 = (surface_up + tangent * 0.22).normalized()
		var powerup_info: Dictionary = get_surface_spawn_from_direction(powerup_dir, 220.0, ground_spawn_surface_offset)
		powerup.global_position = powerup_info.get("point", global_position + powerup_dir * planet_radius)


func _estimate_body_clearance(body: Node3D) -> float:
	var collider: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null or collider.shape == null:
		return rover_spawn_surface_offset
	var shape: Shape3D = collider.shape
	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		return maxf(8.0, maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.75)
	if shape is SphereShape3D:
		return maxf(8.0, (shape as SphereShape3D).radius * 1.6)
	if shape is CapsuleShape3D:
		var cap: CapsuleShape3D = shape as CapsuleShape3D
		return maxf(8.0, (cap.height * 0.5) + cap.radius * 1.2)
	if shape is CylinderShape3D:
		var cyl: CylinderShape3D = shape as CylinderShape3D
		return maxf(8.0, (cyl.height * 0.5) + cyl.radius)
	return rover_spawn_surface_offset
