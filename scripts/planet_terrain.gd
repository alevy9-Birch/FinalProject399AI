extends StaticBody3D

## Procedural sphere with layered noise displacement (hills / mountains).
## Builds mesh + concave trimesh collision once on ready.

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


func _ready() -> void:
	var macro: FastNoiseLite = FastNoiseLite.new()
	macro.seed = 90210
	macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro.frequency = 0.55
	macro.fractal_octaves = 4
	macro.fractal_lacunarity = 2.05
	macro.fractal_gain = 0.48

	var ridge: FastNoiseLite = FastNoiseLite.new()
	ridge.seed = 4102
	ridge.noise_type = FastNoiseLite.TYPE_PERLIN
	ridge.frequency = 0.9
	ridge.fractal_octaves = 3
	ridge.fractal_lacunarity = 2.2
	ridge.fractal_gain = 0.55

	var detail: FastNoiseLite = FastNoiseLite.new()
	detail.seed = 771
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

	var trimesh: Shape3D = arr_mesh.create_trimesh_shape()
	if trimesh != null:
		_collision_shape.shape = trimesh
