extends Node3D

@export var star_count: int = 900
@export var field_radius: float = 4200.0


func _ready() -> void:
	_build_starfield()


func _build_starfield() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = max(64, star_count)
	var dot := SphereMesh.new()
	dot.radius = 0.9
	dot.height = 1.8
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = mm
	mm.mesh = dot
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.92, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.82, 0.9, 1.0, 1.0)
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stars.material_override = mat
	add_child(stars)
	var rng := RandomNumberGenerator.new()
	rng.seed = 498221
	for i in range(mm.instance_count):
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		if dir.length_squared() < 0.001:
			dir = Vector3.FORWARD
		var dist: float = rng.randf_range(field_radius * 0.75, field_radius)
		var p: Vector3 = dir * dist
		var s: float = rng.randf_range(0.6, 2.4)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))
