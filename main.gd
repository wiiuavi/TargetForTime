extends Node3D

var targetScene: PackedScene = preload("res://target.tscn")

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D

enum GameState { TITLE, COUNTDOWN, PLAYING, PAUSED, GAME_OVER }
var currentState: GameState = GameState.TITLE

var timeLeft: float = 25.0
var stopwatch: float = 0.0
var targetsHit: int = 0
var shotsFired: int = 0

var suddenDeath: bool = false
var doubleSpeed: bool = false
var blinkTimer: float = 0.0

var sensitivity: float = 0.001
var savePath: String = "user://settings.cfg"

@onready var crosshairRect: TextureRect = $CanvasLayer/crosshair
@onready var redTint: ColorRect = $CanvasLayer/RedTint
@onready var hud: Control = $CanvasLayer/HUD
@onready var timerLabel: Label = $CanvasLayer/HUD/TimerLabel
@onready var stopwatchLabel: Label = $CanvasLayer/HUD/StopwatchLabel
@onready var hudStatsLabel: Label = $CanvasLayer/HUD.find_child("StatsLabel", true, false)

@onready var pauseMenu: Control = $CanvasLayer/PauseMenu
@onready var resumeButton: Button = $CanvasLayer/PauseMenu.find_child("ResumeButton", true, false)
@onready var pauseTitleButton: Button = $CanvasLayer/PauseMenu.find_child("PauseTitleButton", true, false)
@onready var quitButton: Button = $CanvasLayer/PauseMenu.find_child("QuitButton", true, false)
@onready var sensSlider: HSlider = $CanvasLayer/PauseMenu/MenuBox/SensBox.find_child("SensSlider", true, false) if has_node("CanvasLayer/PauseMenu/MenuBox/SensBox") else $CanvasLayer/PauseMenu.find_child("SensSlider", true, false)
@onready var sizeSlider: HSlider = $CanvasLayer/PauseMenu/MenuBox/CrosshairSizeBox.find_child("SizeSlider", true, false) if has_node("CanvasLayer/PauseMenu/MenuBox/CrosshairSizeBox") else $CanvasLayer/PauseMenu.find_child("SizeSlider", true, false)

@onready var titleScreen: Control = $CanvasLayer/TitleScreen
@onready var startButton: Button = $CanvasLayer/TitleScreen.find_child("StartButton", true, false)
@onready var titleQuitButton: Button = $CanvasLayer/TitleScreen.find_child("TitleQuitButton", true, false)
@onready var titleSensSlider: HSlider = $CanvasLayer/TitleScreen/TitleSensBox.find_child("SensSlider", true, false) if has_node("CanvasLayer/TitleScreen/TitleSensBox") else $CanvasLayer/TitleScreen.find_child("SensSlider", true, false)
@onready var titleSizeSlider: HSlider = $CanvasLayer/TitleScreen/TitleSizeBox.find_child("SizeSlider", true, false) if has_node("CanvasLayer/TitleScreen/TitleSizeBox") else $CanvasLayer/TitleScreen.find_child("SizeSlider", true, false)

@onready var gameOverScreen: Control = $CanvasLayer/GameOverScreen
@onready var playAgainButton: Button = $CanvasLayer/GameOverScreen.find_child("PlayAgainButton", true, false)
@onready var titleButton: Button = $CanvasLayer/GameOverScreen.find_child("TitleButton", true, false)
@onready var gameOverStatsLabel: Label = $CanvasLayer/GameOverScreen.find_child("GameOverStatsLabel", true, false)

var activePopups: Array[Label] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	setupUILayouts()
	
	if startButton: startButton.pressed.connect(_onStartPressed)
	if titleQuitButton: titleQuitButton.pressed.connect(_onQuitPressed)
	
	if resumeButton: resumeButton.pressed.connect(_onResumePressed)
	if pauseTitleButton: pauseTitleButton.pressed.connect(_onTitlePressed)
	if quitButton: quitButton.pressed.connect(_onQuitPressed)
	
	if playAgainButton: playAgainButton.pressed.connect(_onPlayAgainPressed)
	if titleButton: titleButton.pressed.connect(_onTitlePressed)
	
	var sensSliders: Array[HSlider] = []
	if sensSlider: sensSliders.append(sensSlider)
	if titleSensSlider: sensSliders.append(titleSensSlider)
	for slider in sensSliders:
		slider.min_value = 0.0001
		slider.max_value = 0.005
		slider.step = 0.0001
		slider.value_changed.connect(_onSensitivityChanged)
		
	var sizeSliders: Array[HSlider] = []
	if sizeSlider: sizeSliders.append(sizeSlider)
	if titleSizeSlider: sizeSliders.append(titleSizeSlider)
	for slider in sizeSliders:
		slider.min_value = 0.1
		slider.max_value = 3.0
		slider.step = 0.1
		slider.value_changed.connect(_onCrosshairSizeChanged)
	
	crosshairRect.pivot_offset = crosshairRect.size / 2.0
	
	loadSettings()
	goToTitleScreen()

func setupUILayouts() -> void:
	var screenWidth = get_viewport().get_visible_rect().size.x
	var screenHeight = get_viewport().get_visible_rect().size.y
	
	for screen in [titleScreen, pauseMenu, gameOverScreen, hud]:
		if screen:
			screen.anchors_preset = Control.PRESET_FULL_RECT
			screen.mouse_filter = Control.MOUSE_FILTER_IGNORE if screen == hud else Control.MOUSE_FILTER_STOP
			
	if redTint:
		redTint.anchors_preset = Control.PRESET_FULL_RECT
		redTint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if hudStatsLabel:
		hudStatsLabel.anchors_preset = Control.PRESET_TOP_LEFT
		hudStatsLabel.position = Vector2(20, 20)
		hudStatsLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	if timerLabel:
		timerLabel.anchors_preset = Control.PRESET_TOP_RIGHT
		timerLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		timerLabel.position = Vector2(screenWidth - 220, 20)

	if stopwatchLabel:
		stopwatchLabel.anchors_preset = Control.PRESET_TOP_RIGHT
		stopwatchLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stopwatchLabel.position = Vector2(screenWidth - 220, 70)

	if gameOverScreen:
		var bg = gameOverScreen.find_child("ColorRect", true, false)
		if bg:
			bg.anchors_preset = Control.PRESET_FULL_RECT
			bg.color = Color(0, 0, 0, 0.85)

		var goTitle = gameOverScreen.find_child("Label", true, false)
		if goTitle and goTitle != gameOverStatsLabel:
			goTitle.text = "GAME OVER"
			goTitle.add_theme_font_size_override("font_size", 56)
			goTitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			goTitle.size = Vector2(400, 70)
			goTitle.position = Vector2((screenWidth - 400) / 2.0, screenHeight * 0.15)

		if gameOverStatsLabel:
			gameOverStatsLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gameOverStatsLabel.add_theme_font_size_override("font_size", 26)
			gameOverStatsLabel.size = Vector2(360, 160)
			gameOverStatsLabel.position = Vector2(
				(screenWidth - 360) / 2.0,
				screenHeight * 0.32
			)

		var buttonWidth = 320.0
		var buttonHeight = 50.0

		if playAgainButton:
			playAgainButton.custom_minimum_size = Vector2(buttonWidth, buttonHeight)
			playAgainButton.size = Vector2(buttonWidth, buttonHeight)
			playAgainButton.add_theme_font_size_override("font_size", 22)
			playAgainButton.position = Vector2(
				(screenWidth - buttonWidth) / 2.0,
				screenHeight * 0.62
			)

		if titleButton:
			titleButton.custom_minimum_size = Vector2(buttonWidth, buttonHeight)
			titleButton.size = Vector2(buttonWidth, buttonHeight)
			titleButton.add_theme_font_size_override("font_size", 22)
			titleButton.position = Vector2(
				(screenWidth - buttonWidth) / 2.0,
				screenHeight * 0.73
			)

func _process(delta: float) -> void:
	if currentState == GameState.PLAYING:
		if doubleSpeed:
			timeLeft -= (delta * 2.0)
			
			blinkTimer += delta * 6.0
			if int(blinkTimer) % 2 == 0:
				timerLabel.add_theme_color_override("font_color", Color.WHITE)
			else:
				timerLabel.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		else:
			timeLeft -= delta
			
		stopwatch += delta
		
		if stopwatch >= 30.0 and not suddenDeath:
			triggerSuddenDeath()
			
		if stopwatch >= 60.0 and not doubleSpeed:
			doubleSpeed = true
			
		if timeLeft <= 0:
			timeLeft = 0
			triggerGameOver()
			
		updateHUD()

func _unhandled_input(event: InputEvent) -> void:
	if currentState == GameState.PLAYING and event.is_action_pressed("ui_cancel"):
		togglePause()

	if currentState == GameState.PLAYING and not get_tree().paused and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * sensitivity
		camera.rotation.x -= event.relative.y * sensitivity
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if currentState == GameState.PLAYING and not get_tree().paused:
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				shoot()

func shoot() -> void:
	shotsFired += 1
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.has_method("onHit"):
			targetsHit += 1
			
			var dist = camera.global_position.distance_to(collider.global_position)
			var timeBonus = 0.0
			
			if dist > 6.0: timeBonus = 0.5
			elif dist > 4.0: timeBonus = 0.25
			else: timeBonus = 0.125
			
			if suddenDeath:
				timeBonus /= 2.0
				
			timeLeft += timeBonus
			showTimePopup(timeBonus, true)
			
			collider.onHit()
			spawnTarget()
			return
	
	timeLeft -= 1.0
	showTimePopup(-1.0, false)

func spawnTarget() -> void:
	var newTarget = targetScene.instantiate()
	newTarget.add_to_group("targets")
	
	var randX = randf_range(-4.0, 4.0)
	var randY = randf_range(0.5, 3.0)
	var randZ = randf_range(-4.0, -8.0)
	
	newTarget.position = Vector3(randX, randY, randZ)
	add_child(newTarget)

func clearTargets() -> void:
	for node in get_tree().get_nodes_in_group("targets"):
		node.queue_free()

func resetGameData() -> void:
	timeLeft = 25.0
	stopwatch = 0.0
	targetsHit = 0
	shotsFired = 0
	suddenDeath = false
	doubleSpeed = false
	blinkTimer = 0.0
	redTint.hide()
	timerLabel.add_theme_color_override("font_color", Color.WHITE)
	clearTargets()
	updateHUD()

func goToTitleScreen() -> void:
	get_tree().paused = false
	currentState = GameState.TITLE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	titleScreen.show()
	gameOverScreen.hide()
	pauseMenu.hide()
	hud.hide()
	redTint.hide()
	crosshairRect.hide()
	
	if startButton: startButton.text = "Start Game"
	if playAgainButton: playAgainButton.text = "Play Again"
	clearTargets()

func _onStartPressed() -> void:
	currentState = GameState.COUNTDOWN
	
	if titleSensSlider: titleSensSlider.editable = false
	if titleSizeSlider: titleSizeSlider.editable = false
	if titleQuitButton: titleQuitButton.disabled = true
	
	if startButton: startButton.text = "3"
	await get_tree().create_timer(1.0).timeout
	if startButton: startButton.text = "2"
	await get_tree().create_timer(1.0).timeout
	if startButton: startButton.text = "1"
	await get_tree().create_timer(1.0).timeout
	
	if titleSensSlider: titleSensSlider.editable = true
	if titleSizeSlider: titleSizeSlider.editable = true
	if titleQuitButton: titleQuitButton.disabled = false
	startGame()

func _onPlayAgainPressed() -> void:
	currentState = GameState.COUNTDOWN
	
	if titleButton: titleButton.disabled = true
	
	if playAgainButton: playAgainButton.text = "3"
	await get_tree().create_timer(1.0).timeout
	if playAgainButton: playAgainButton.text = "2"
	await get_tree().create_timer(1.0).timeout
	if playAgainButton: playAgainButton.text = "1"
	await get_tree().create_timer(1.0).timeout
	
	if titleButton: titleButton.disabled = false
	startGame()

func startGame() -> void:
	resetGameData()
	currentState = GameState.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	titleScreen.hide()
	gameOverScreen.hide()
	hud.show()
	crosshairRect.show()
	
	for i in range(3):
		spawnTarget()

func togglePause() -> void:
	var isPaused = get_tree().paused
	get_tree().paused = !isPaused
	
	if get_tree().paused:
		currentState = GameState.PAUSED
		pauseMenu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		currentState = GameState.PLAYING
		pauseMenu.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func triggerSuddenDeath() -> void:
	suddenDeath = true
	redTint.show()
	timerLabel.add_theme_color_override("font_color", Color(1, 0.2, 0.2))

func triggerGameOver() -> void:
	currentState = GameState.GAME_OVER
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide()
	crosshairRect.hide()
	redTint.hide()
	
	if playAgainButton:
		playAgainButton.text = "Play Again"
	
	var accuracy = 0.0
	if shotsFired > 0:
		accuracy = (float(targetsHit) / float(shotsFired)) * 100.0
		
	if gameOverStatsLabel:
		gameOverStatsLabel.text = "Time Survived: %s\nTargets Hit: %d\nShots Fired: %d\nAccuracy: %.1f%%" % [formatTime(stopwatch), targetsHit, shotsFired, accuracy]
	
	gameOverScreen.show()

func updateHUD() -> void:
	timerLabel.text = formatTime(timeLeft)
	stopwatchLabel.text = formatTime(stopwatch)
	
	if hudStatsLabel:
		hudStatsLabel.text = "Hits: %d | Shots: %d" % [targetsHit, shotsFired]

func formatTime(time: float) -> String:
	var m = int(time) / 60
	var s = int(time) % 60
	var ms = int(fmod(time, 1.0) * 100)
	return "%02d:%02d:%02d" % [m, s, ms]

func showTimePopup(amount: float, isHit: bool) -> void:
	var lbl = Label.new()
	lbl.text = ("+" if amount > 0 else "") + "%.2f" % amount
	lbl.add_theme_font_size_override("font_size", 28)
	
	if isHit:
		lbl.add_theme_color_override("font_color", Color.GREEN if not suddenDeath else Color.ORANGE)
	else:
		lbl.add_theme_color_override("font_color", Color.RED)
	
	hud.add_child(lbl)
	
	var startX = get_viewport().get_visible_rect().size.x + 50
	var targetX = get_viewport().get_visible_rect().size.x - 100
	lbl.position = Vector2(startX, 80)
	
	activePopups.append(lbl)
	updatePopupPositions()
	
	var tweenIn = create_tween()
	tweenIn.tween_property(lbl, "position:x", targetX, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(0.25).timeout
	
	if is_instance_valid(lbl):
		var tweenOut = create_tween()
		tweenOut.tween_property(lbl, "position:x", startX, 0.15).set_ease(Tween.EASE_IN)
		await tweenOut.finished
		
		if is_instance_valid(lbl):
			activePopups.erase(lbl)
			lbl.queue_free()
			updatePopupPositions()

func updatePopupPositions() -> void:
	var currentY = 80
	for i in range(activePopups.size() - 1, -1, -1):
		var lbl = activePopups[i]
		if is_instance_valid(lbl):
			var tween = create_tween()
			tween.tween_property(lbl, "position:y", currentY, 0.1)
			currentY += 40

func _onResumePressed() -> void:
	togglePause()

func _onTitlePressed() -> void:
	goToTitleScreen()

func _onQuitPressed() -> void:
	get_tree().quit()

func loadSettings() -> void:
	var config = ConfigFile.new()
	var error = config.load(savePath)
	if error == OK:
		sensitivity = config.get_value("settings", "sensitivity", 0.001)
		var savedSize = config.get_value("settings", "crosshairSize", 1.0)
		crosshairRect.scale = Vector2(savedSize, savedSize)
		
	if sensSlider: sensSlider.set_value_no_signal(sensitivity)
	if titleSensSlider: titleSensSlider.set_value_no_signal(sensitivity)
	if sizeSlider: sizeSlider.set_value_no_signal(crosshairRect.scale.x)
	if titleSizeSlider: titleSizeSlider.set_value_no_signal(crosshairRect.scale.x)

func saveSettings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "sensitivity", sensitivity)
	config.set_value("settings", "crosshairSize", crosshairRect.scale.x)
	config.save(savePath)

func _onSensitivityChanged(newValue: float) -> void:
	sensitivity = newValue
	if sensSlider: sensSlider.set_value_no_signal(newValue)
	if titleSensSlider: titleSensSlider.set_value_no_signal(newValue)
	saveSettings()

func _onCrosshairSizeChanged(newSize: float) -> void:
	crosshairRect.scale = Vector2(newSize, newSize)
	if sizeSlider: sizeSlider.set_value_no_signal(newSize)
	if titleSizeSlider: titleSizeSlider.set_value_no_signal(newSize)
	saveSettings()
