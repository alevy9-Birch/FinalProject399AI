extends StaticBody3D

## Procedural sphere with layered noise displacement (hills / mountains).
## Builds mesh + concave trimesh collision once on ready.

const ORE_DEPOSIT_SCRIPT := preload("res://scripts/ore_deposit.gd")

@export var planet_radius: float = 980.0
@export var rings: int = 64
@export var radial_segments: int = 128
@export var macro_height: float = 40.0
@export var ridge_height: float = 10.0
@export var detail_height: float = 1.2
@export var noise_macro_scale: float = 1.9
@export var noise_ridge_scale: float = 5.6
@export var noise_detail_scale: float = 16.0

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


func _spawn_props(mission: Dictionary, macro: FastNoiseLite, ridge: FastNoiseLite, detail: FastNoiseLite) -> void:
	_clear_existing_props()
	if mission.is_empty():
		return

	var mission_seed: int = int(mission.get("mission_seed", 1))
	var prop_density: float = float(mission.get("prop_density", 0.01))
	var prop_profile: int = int(mission.get("prop_profile", 0))
	var prop_count: int = clampi(int(1200.0 * prop_density), 4, 140)
	var rng := RandomNumberGenerator.new()
	rng.seed = mission_seed + 404

	for i in range(prop_count):
		var dir := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		if dir.length_squared() < 0.001:
			continue
		var surface_point: Vector3 = _sample_surface_point(dir, macro, ridge, detail)
		var prop := _build_prop(prop_profile, rng)
		if prop == null:
			continue
		prop.position = surface_point
		prop.basis = Basis.looking_at(dir, Vector3.RIGHT)
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
		var surface_point: Vector3 = _sample_surface_point(dir, macro, ridge, detail)
		var ore := Node3D.new()
		ore.name = "OreDeposit_%d" % i
		ore.set_script(ORE_DEPOSIT_SCRIPT)
		ore.set("ore_value", rng.randi_range(yield_range.x, max(yield_range.x, yield_range.y)))
		ore.position = surface_point
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


func _make_prop_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _apply_surface_material(mission: Dictionary) -> void:
	var base: StandardMaterial3D = _mesh_instance.material_override as StandardMaterial3D
	var mat: StandardMaterial3D = base.duplicate() as StandardMaterial3D if base != null else StandardMaterial3D.new()
	var planet_type: int = int(mission.get("planet_type", 0))
	var mission_seed: int = int(mission.get("mission_seed", 1))
	var tex_frequency: float = 0.07
	var tex_contrast: float = 1.0
	var tex_scale: Vector3 = Vector3(18.0, 18.0, 18.0)
	match planet_type:
		0:
			mat.albedo_color = Color(0.41, 0.36, 0.32, 1.0)
			tex_frequency = 0.095
			tex_contrast = 1.28
			tex_scale = Vector3(13.0, 13.0, 13.0)
		1:
			mat.albedo_color = Color(0.5, 0.47, 0.42, 1.0)
			tex_frequency = 0.065
			tex_contrast = 1.1
			tex_scale = Vector3(17.0, 17.0, 17.0)
		2:
			mat.albedo_color = Color(0.52, 0.54, 0.58, 1.0)
			mat.metallic = 0.2
			tex_frequency = 0.11
			tex_contrast = 1.45
			tex_scale = Vector3(11.5, 11.5, 11.5)
		3:
			mat.albedo_color = Color(0.45, 0.27, 0.2, 1.0)
			tex_frequency = 0.12
			tex_contrast = 1.55
			tex_scale = Vector3(11.0, 11.0, 11.0)
		4:
			mat.albedo_color = Color(0.76, 0.84, 0.88, 1.0)
			tex_frequency = 0.055
			tex_contrast = 0.95
			tex_scale = Vector3(21.0, 21.0, 21.0)
		5:
			mat.albedo_color = Color(0.3, 0.44, 0.31, 1.0)
			tex_frequency = 0.082
			tex_contrast = 1.22
			tex_scale = Vector3(14.0, 14.0, 14.0)
		6:
			mat.albedo_color = Color(0.72, 0.58, 0.36, 1.0)
			tex_frequency = 0.07
			tex_contrast = 1.18
			tex_scale = Vector3(18.0, 18.0, 18.0)
		7:
			mat.albedo_color = Color(0.24, 0.43, 0.28, 1.0)
			tex_frequency = 0.1
			tex_contrast = 1.35
			tex_scale = Vector3(12.5, 12.5, 12.5)
	var tex_noise := FastNoiseLite.new()
	tex_noise.seed = mission_seed + 808
	tex_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	tex_noise.frequency = tex_frequency
	tex_noise.fractal_octaves = 4
	tex_noise.fractal_lacunarity = 2.05
	tex_noise.fractal_gain = 0.52
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.width = 1024
	tex.height = 1024
	tex.normalize = false
	tex.in_3d_space = true
	tex.as_normal_map = false
	tex.generate_mipmaps = true
	tex.noise = tex_noise
	mat.albedo_texture = tex
	mat.albedo_texture_force_srgb = true
	mat.uv1_triplanar = true
	mat.uv1_scale = tex_scale
	mat.roughness = clampf(0.82 + 0.08 * tex_contrast, 0.78, 0.96)
	_mesh_instance.material_override = mat


func _position_rover_spawn(mission: Dictionary, macro: FastNoiseLite, ridge: FastNoiseLite, detail: FastNoiseLite) -> void:
	var rover: Node3D = get_node_or_null("../Rover") as Node3D
	if rover == null:
		return
	var up := Vector3.UP
	var surface: Vector3 = _sample_surface_point(up, macro, ridge, detail)
	var spawn_altitude: float = 10.0 + clampf(planet_radius * 0.04, 10.0, 70.0)
	rover.global_position = global_position + surface + up * spawn_altitude
	if rover is RigidBody3D:
		var rb: RigidBody3D = rover as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	var powerup: Area3D = get_node_or_null("../JetpackPowerup") as Area3D
	if powerup != null:
		var tangent: Vector3 = up.cross(Vector3.RIGHT)
		if tangent.length_squared() < 0.01:
			tangent = up.cross(Vector3.FORWARD)
		tangent = tangent.normalized()
		powerup.global_position = global_position + surface + tangent * 34.0 + up * 4.0
