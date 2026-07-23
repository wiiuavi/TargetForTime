extends Area3D

signal targetClicked(timeBonus: float)

@export var timeBonus: float = 2.0

func onHit() -> void:
	targetClicked.emit(timeBonus)
	queue_free()
