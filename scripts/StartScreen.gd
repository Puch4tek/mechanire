extends Control

@onready var start_button: Button = $Button

var is_starting: bool = false

func _ready() -> void:
	if start_button and not start_button.pressed.is_connected(_on_button_pressed):
		start_button.pressed.connect(_on_button_pressed)

func _input(event: InputEvent) -> void:
	if is_starting:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			start_game()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			start_game()
			get_viewport().set_input_as_handled()

func start_game() -> void:
	if is_starting:
		return
	is_starting = true

	if has_node("/root/Transition") and Transition.has_method("fade_to_scene"):
		Transition.fade_to_scene("res://scenes/Game.tscn")
	else:
		# Fallback keeps start working even if autoload is missing in editor run config.
		get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_button_pressed() -> void:
	start_game()
