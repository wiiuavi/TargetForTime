extends Area3D

func _ready() -> void:
	var camera = get_viewport().get_camera_3d()
	if camera:
		look_at(camera.global_position, Vector3.UP)
		rotate_y(deg_to_rad(180))

func onHit() -> void:
	queue_free()
	
