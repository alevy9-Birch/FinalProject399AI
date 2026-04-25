extends Area3D

var velocity: Vector3 = Vector3.ZERO
var life_remaining: float = 8.0
var knockback_force: float = 18.0
var owner_enemy: Node3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	life_remaining -= delta
	if life_remaining <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == owner_enemy:
		return
	if body.has_method("apply_external_knockback"):
		body.apply_external_knockback(velocity.normalized() * knockback_force)
	queue_free()
