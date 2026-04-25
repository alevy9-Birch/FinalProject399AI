extends Node3D

## Third-person orbit:
## - Generic mouse-look behavior (yaw + pitch).
## - Yaw axis is always local planetary up = (rover - planet_center).
## - Pitch is around the camera-right axis after yaw.

@export var mouse_sensitivity: float = 0.0035
@export var min_pitch_degrees: float = -55.0
@export var max_pitch_degrees: float = 40.0
@export var planet_path: NodePath = NodePath("../Planet")

var _pitch: float = -0.28
var _pending_yaw_delta: float = 0.0

@onready var _body: Node3D = get_parent() as Node3D
@onready var _pitch_pivot: Node3D = $PitchPivot

var _planet: Node3D
var _desired_back_world: Vector3 = Vector3.BACK


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_resolve_planet()
	var up_w: Vector3 = _get_planet_up_world()
	var initial_back: Vector3 = _body.global_basis.z.slide(up_w)
	if initial_back.length_squared() < 1e-6:
		initial_back = Vector3.BACK.slide(up_w)
	_desired_back_world = initial_back.normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pending_yaw_delta -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		var min_pitch: float = deg_to_rad(min_pitch_degrees)
		var max_pitch: float = deg_to_rad(max_pitch_degrees)
		_pitch = clamp(_pitch, min_pitch, max_pitch)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if _body == null:
		return
	_resolve_planet()
	var up_w: Vector3 = _get_planet_up_world()
	# Keep stored orbit vector tangent to current local horizon as rover moves on sphere.
	_desired_back_world = _desired_back_world.slide(up_w)
	if _desired_back_world.length_squared() < 1e-6:
		_desired_back_world = _body.global_basis.z.slide(up_w)
	if _desired_back_world.length_squared() < 1e-6:
		_desired_back_world = Vector3.BACK.slide(up_w)
	_desired_back_world = _desired_back_world.normalized()

	# Yaw around local planetary up.
	if absf(_pending_yaw_delta) > 1e-6:
		_desired_back_world = _desired_back_world.rotated(up_w, _pending_yaw_delta).slide(up_w).normalized()
		_pending_yaw_delta = 0.0

	# Build yaw-only rig basis from local planetary up and desired back direction.
	var inv_body: Basis = _body.global_transform.basis.inverse()
	var z_local: Vector3 = inv_body * _desired_back_world
	var y_local: Vector3 = inv_body * up_w
	if z_local.length_squared() < 1e-8 or y_local.length_squared() < 1e-8:
		return
	z_local = z_local.normalized()
	y_local = y_local.normalized()
	# Orthonormalize so Y stays planet-up and Z stays horizon-back view direction.
	var x_local: Vector3 = y_local.cross(z_local).normalized()
	z_local = x_local.cross(y_local).normalized()
	var b: Basis = Basis(x_local, y_local, z_local).orthonormalized()
	transform.basis = b
	transform.origin = Vector3(0, 1.5, 0)
	# Local camera pitch (up/down) happens on pitch pivot around local X.
	_pitch_pivot.rotation = Vector3(_pitch, 0.0, 0.0)


func _resolve_planet() -> void:
	if _planet != null and is_instance_valid(_planet):
		return
	if not planet_path.is_empty():
		_planet = get_node_or_null(planet_path) as Node3D
	if _planet != null:
		return
	var found: Array[Node] = get_tree().get_nodes_in_group("gravity_source")
	if found.is_empty():
		_planet = null
	else:
		_planet = found[0] as Node3D


func _get_planet_up_world() -> Vector3:
	if _planet == null:
		return Vector3.UP
	var up: Vector3 = _body.global_position - _planet.global_position
	if up.length_squared() < 1e-8:
		return Vector3.UP
	return up.normalized()
