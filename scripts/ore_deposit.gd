extends Node3D

@export var ore_value: int = 1
var _collected: bool = false


func is_collected() -> bool:
	return _collected


func collect() -> int:
	if _collected:
		return 0
	_collected = true
	return ore_value
