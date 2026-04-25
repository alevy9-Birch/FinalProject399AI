extends Area3D

var _rover: RigidBody3D
var _spin: float = 0.0


func _ready() -> void:
	_rover = get_node_or_null("../Rover") as RigidBody3D
	body_entered.connect(_on_body_entered)
	_build_visual()


func _process(delta: float) -> void:
	_spin += delta * 1.8
	rotation.y = _spin


func _on_body_entered(body: Node) -> void:
	if body != _rover:
		return
	if body.has_method("activate_permanent_thrusters"):
		body.activate_permanent_thrusters()
	queue_free()


func _build_visual() -> void:
	var mesh := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.42
	c.height = 0.85
	mesh.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.9, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.95, 1.0, 1.0)
	mat.emission_energy_multiplier = 1.7
	mesh.material_override = mat
	add_child(mesh)
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.72
	col.shape = sphere
	add_child(col)
