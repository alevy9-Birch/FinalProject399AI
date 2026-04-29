extends Node3D

const EnemyActorScript := preload("res://scripts/enemy_actor.gd")

@export var spawn_interval_start: float = 16.0
@export var spawn_interval_min: float = 6.0
@export var difficulty_ramp: float = 0.35

var _spawn_timer: float = 0.0
var _elapsed: float = 0.0
var _rover: RigidBody3D
var _planet: Node3D
var _planet_radius: float = 760.0


func _ready() -> void:
	_rover = get_node_or_null("../Rover") as RigidBody3D
	_planet = get_node_or_null("../Planet") as Node3D
	if _planet != null and _planet.has_method("get"):
		_planet_radius = float(_planet.get("planet_radius"))
	_spawn_timer = spawn_interval_start


func _physics_process(delta: float) -> void:
	if _rover == null or not is_instance_valid(_rover):
		return
	_elapsed += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_wave()
		var current: float = maxf(spawn_interval_min, spawn_interval_start - _elapsed * difficulty_ramp * 0.1)
		_spawn_timer = current + randf_range(-1.0, 1.0)


func _spawn_wave() -> void:
	var roll: float = randf()
	if roll < 0.58:
		_spawn_minion_group()
	elif roll < 0.83:
		_spawn_turret()
	else:
		_spawn_ufo()


func _spawn_minion_group() -> void:
	if _planet == null:
		return
	for i in range(3):
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var actor := _new_actor(0)
		var spawn_point: Vector3 = _resolve_planet_spawn_point(dir, 320.0, _enemy_surface_offset(), [actor, _rover])
		actor.global_position = spawn_point


func _spawn_turret() -> void:
	if _planet == null:
		return
	var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var actor := _new_actor(1)
	actor.global_position = _resolve_planet_spawn_point(dir, 300.0, 1.0, [actor, _rover])


func _spawn_ufo() -> void:
	if _planet == null:
		return
	var up: Vector3 = (_rover.global_position - _planet.global_position).normalized()
	var base_point: Vector3 = _resolve_planet_spawn_point(up, 320.0, 1.0, [_rover])
	var tangent := up.cross(Vector3.RIGHT)
	if tangent.length_squared() < 0.01:
		tangent = up.cross(Vector3.FORWARD)
	tangent = tangent.normalized()
	var spawn_pos: Vector3 = base_point + up * 78.0 + tangent * randf_range(-24.0, 24.0)
	var actor := _new_actor(2)
	actor.global_position = spawn_pos


func _new_actor(kind: int) -> Area3D:
	var actor := Area3D.new()
	actor.set_script(EnemyActorScript)
	add_child(actor)
	actor.setup(kind, _rover, _planet, _planet_radius)
	return actor


func _resolve_planet_spawn_point(dir: Vector3, cast_extra: float, offset: float, exclude: Array = []) -> Vector3:
	if _planet != null and _planet.has_method("get_surface_spawn_from_direction"):
		var info: Dictionary = _planet.get_surface_spawn_from_direction(dir, cast_extra, offset, exclude)
		return info.get("point", _planet.global_position + dir.normalized() * (_planet_radius + offset))
	return _planet.global_position + dir.normalized() * (_planet_radius + offset)


func _enemy_surface_offset() -> float:
	if _planet != null and _planet.has_method("get"):
		return float(_planet.get("enemy_spawn_surface_offset"))
	return 24.0
