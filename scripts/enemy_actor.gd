extends Area3D

const EnemyProjectileScript := preload("res://scripts/enemy_projectile.gd")

enum EnemyType {
	MINION,
	TURRET,
	UFO
}

var enemy_type: int = EnemyType.MINION
var health: float = 10.0
var rover: RigidBody3D
var planet: Node3D
var radius_hint: float = 800.0
var fire_timer: float = 0.0
var noise_phase: float = 0.0
var drift_axis: Vector3 = Vector3.UP
var warning_timer: float = 0.0
var warning_line: MeshInstance3D


func setup(kind: int, rover_ref: RigidBody3D, planet_ref: Node3D, planet_radius: float) -> void:
	enemy_type = kind
	rover = rover_ref
	planet = planet_ref
	radius_hint = planet_radius
	match enemy_type:
		EnemyType.MINION:
			health = 16.0
			fire_timer = randf_range(1.2, 2.6)
		EnemyType.TURRET:
			health = 38.0
			fire_timer = randf_range(2.0, 4.0)
		EnemyType.UFO:
			health = 26.0
			fire_timer = randf_range(2.8, 4.5)
	noise_phase = randf_range(0.0, TAU)
	drift_axis = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_build_visuals()


func apply_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	if rover == null or not is_instance_valid(rover):
		return
	match enemy_type:
		EnemyType.MINION:
			_update_minion(delta)
		EnemyType.TURRET:
			_update_turret(delta)
		EnemyType.UFO:
			_update_ufo(delta)


func _update_minion(delta: float) -> void:
	var to_player: Vector3 = rover.global_position - global_position
	var tangent_noise: Vector3 = drift_axis.cross(to_player.normalized()).normalized()
	noise_phase += delta * 1.9
	var noisy: Vector3 = tangent_noise * sin(noise_phase * 1.7) * 7.5
	global_position += (to_player.normalized() * 5.6 + noisy) * delta
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = randf_range(1.4, 2.8)
		_fire_projectile((rover.global_position - global_position).normalized(), 14.0, 10.0, Color(0.85, 0.45, 0.45, 1.0))


func _update_turret(delta: float) -> void:
	if warning_timer > 0.0:
		warning_timer -= delta
		if warning_line != null:
			warning_line.visible = true
			_update_warning_line()
		if warning_timer <= 0.0:
			_fire_turret_hitscan()
			if warning_line != null:
				warning_line.visible = false
		return
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = randf_range(3.0, 5.2)
		warning_timer = 1.0
		if warning_line != null:
			warning_line.visible = true
			_update_warning_line()


func _update_ufo(delta: float) -> void:
	var surface_up: Vector3 = (global_position - planet.global_position).normalized() if planet != null else Vector3.UP
	var desired_pos: Vector3 = rover.global_position + surface_up * 70.0
	global_position = global_position.lerp(desired_pos, clampf(delta * 0.48, 0.0, 1.0))
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = randf_range(3.5, 5.2)
		var dir: Vector3 = (rover.global_position - global_position).normalized()
		_fire_projectile(dir, 9.0, 34.0, Color(0.5, 0.95, 0.95, 1.0))


func _fire_turret_hitscan() -> void:
	if rover == null:
		return
	var start: Vector3 = global_position + Vector3.UP * 1.4
	var target: Vector3 = rover.global_position
	var query := PhysicsRayQueryParameters3D.create(start, target)
	query.exclude = [self]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] == rover:
		rover.apply_external_knockback((target - start).normalized() * 58.0)


func _fire_projectile(dir: Vector3, speed: float, knockback: float, color: Color) -> void:
	var proj := Area3D.new()
	proj.name = "EnemyProjectile"
	proj.set_script(EnemyProjectileScript)
	proj.global_position = global_position + dir * 1.3
	proj.velocity = dir * speed
	proj.knockback_force = knockback
	proj.owner_enemy = self
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.24
	shape.shape = sphere
	proj.add_child(shape)
	var mesh := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.22
	orb.height = 0.44
	mesh.mesh = orb
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	proj.add_child(mesh)
	get_tree().current_scene.add_child(proj)


func _build_visuals() -> void:
	if warning_line != null and is_instance_valid(warning_line):
		warning_line.queue_free()
	for child in get_children():
		child.queue_free()
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	var mesh := MeshInstance3D.new()
	match enemy_type:
		EnemyType.MINION:
			sphere.radius = 0.7
			var s := SphereMesh.new()
			s.radius = 0.65
			s.height = 1.3
			mesh.mesh = s
			mesh.material_override = _make_enemy_mat(Color(0.8, 0.35, 0.36, 1.0))
		EnemyType.TURRET:
			sphere.radius = 1.05
			var c := CylinderMesh.new()
			c.top_radius = 0.72
			c.bottom_radius = 0.86
			c.height = 2.1
			mesh.mesh = c
			mesh.material_override = _make_enemy_mat(Color(0.64, 0.35, 0.88, 1.0))
			warning_line = MeshInstance3D.new()
			warning_line.mesh = CylinderMesh.new()
			var warn_mat := StandardMaterial3D.new()
			warn_mat.albedo_color = Color(1.0, 0.24, 0.24, 1.0)
			warn_mat.emission_enabled = true
			warn_mat.emission = Color(1.0, 0.2, 0.2, 1.0)
			warn_mat.emission_energy_multiplier = 2.0
			warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			warning_line.material_override = warn_mat
			warning_line.visible = false
			add_child(warning_line)
		EnemyType.UFO:
			sphere.radius = 1.15
			var disc := CylinderMesh.new()
			disc.top_radius = 1.35
			disc.bottom_radius = 1.35
			disc.height = 0.5
			mesh.mesh = disc
			mesh.material_override = _make_enemy_mat(Color(0.28, 0.9, 0.92, 1.0))
	collision.shape = sphere
	add_child(collision)
	add_child(mesh)


func _update_warning_line() -> void:
	if warning_line == null or rover == null:
		return
	var start: Vector3 = global_position + Vector3.UP * 1.4
	var end: Vector3 = rover.global_position
	var distance: float = start.distance_to(end)
	var cyl: CylinderMesh = warning_line.mesh as CylinderMesh
	if cyl != null:
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.08
		cyl.height = maxf(distance, 0.2)
	warning_line.global_position = start.lerp(end, 0.5)
	warning_line.look_at(end, Vector3.UP)
	warning_line.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _make_enemy_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	mat.emission_energy_multiplier = 1.1
	return mat
