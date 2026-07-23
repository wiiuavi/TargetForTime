extends Node3D

var targetScene: PackedScene = preload("res://target.tscn")

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D

@onready var crosshairRect: TextureRect = $CanvasLayer/crosshair
@onready var pauseMenu: Control = $CanvasLayer/PauseMenu
@onready var resumeButton: Button = $CanvasLayer/PauseMenu/MenuBox/ResumeButton
@onready var sensSlider: HSlider = $CanvasLayer/PauseMenu/MenuBox/SensBox/SensSlider
@onready var sizeSlider: HSlider = $CanvasLayer/PauseMenu/MenuBox/CrosshairSizeBox/SizeSlider
@onready var quitButton: Button = $CanvasLayer/PauseMenu/MenuBox/QuitButton

var sensitivity: float = 0.003
var savePath: String = "user://settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	resumeButton.pressed.connect(_onResumePressed)
	quitButton.pressed.connect(_onQuitPressed)
	sensSlider.value_changed.connect(_onSensitivityChanged)
	sizeSlider.value_changed.connect(_onCrosshairSizeChanged)
	
	loadSettings()
	
	sensSlider.value = sensitivity
	sizeSlider.value = crosshairRect.scale.x
	
	crosshairRect.pivot_offset = crosshairRect.size / 2.0
	
	pauseMenu.hide()

	for i in range(3):
		spawnTarget()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		togglePause()

	if not get_tree().paused and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * sensitivity
		camera.rotation.x -= event.relative.y * sensitivity
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not get_tree().paused:
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				shoot()

func togglePause() -> void:
	var currentPause = get_tree().paused
	get_tree().paused = !currentPause
	
	if get_tree().paused:
		pauseMenu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		pauseMenu.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func shoot() -> void:
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.has_method("onHit"):
			collider.onHit()
			spawnTarget()

func spawnTarget() -> void:
	var newTarget = targetScene.instantiate()
	var randX = randf_range(-4.0, 4.0)
	var randY = randf_range(0.5, 3.0)
	var randZ = randf_range(-4.0, -8.0)
	
	newTarget.position = Vector3(randX, randY, randZ)
	add_child(newTarget)

func loadSettings() -> void:
	var config = ConfigFile.new()
	var error = config.load(savePath)
	if error == OK:
		sensitivity = config.get_value("settings", "sensitivity", 0.003)
		var savedSize = config.get_value("settings", "crosshairSize", 1.0)
		crosshairRect.scale = Vector2(savedSize, savedSize)

func saveSettings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "sensitivity", sensitivity)
	config.set_value("settings", "crosshairSize", crosshairRect.scale.x)
	config.save(savePath)

func _onResumePressed() -> void:
	togglePause()

func _onQuitPressed() -> void:
	get_tree().quit()

func _onSensitivityChanged(newValue: float) -> void:
	sensitivity = newValue
	saveSettings()

func _onCrosshairSizeChanged(newSize: float) -> void:
	crosshairRect.scale = Vector2(newSize, newSize)
	saveSettings()
