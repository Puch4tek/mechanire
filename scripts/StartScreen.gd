extends Control

@onready var start_button: Button = $Button
@onready var background: TextureRect = $Background
@onready var background_fill: ColorRect = get_node_or_null("BackgroundFill")

@export var side_fill_color: Color = Color(0.85490197, 0.84705883, 0.79607844, 1.0)

var is_starting: bool = false

func _ready() -> void:
	setup_background_fill()
	configure_background_display()
	get_viewport().size_changed.connect(update_background_layout)

	if background:
		update_background_layout()

	if start_button and not start_button.pressed.is_connected(_on_button_pressed):
		start_button.pressed.connect(_on_button_pressed)

func setup_background_fill() -> void:
	if background_fill == null:
		background_fill = ColorRect.new()
		background_fill.name = "BackgroundFill"
		background_fill.z_index = -20
		background_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_fill.anchors_preset = Control.PRESET_FULL_RECT
		background_fill.anchor_right = 1.0
		background_fill.anchor_bottom = 1.0
		background_fill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		background_fill.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(background_fill)
		move_child(background_fill, 0)

	background_fill.color = side_fill_color

func configure_background_display() -> void:
	if background == null:
		return
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 0.0
	background.anchor_bottom = 0.0

func update_background_layout() -> void:
	if background == null or background.texture == null:
		return

	var tex_size: Vector2 = background.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	var viewport_pos: Vector2 = visible_rect.position
	var viewport_size: Vector2 = visible_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
		viewport_pos = Vector2.ZERO

	if background_fill:
		background_fill.anchor_left = 0.0
		background_fill.anchor_top = 0.0
		background_fill.anchor_right = 0.0
		background_fill.anchor_bottom = 0.0
		background_fill.position = viewport_pos.round()
		background_fill.size = viewport_size.round()

	var scale_by_height: float = viewport_size.y / tex_size.y
	var draw_size: Vector2 = tex_size * scale_by_height
	var offset_x: float = (viewport_size.x - draw_size.x) * 0.5
	var offset_y: float = (viewport_size.y - draw_size.y) * 0.5
	background.position = (viewport_pos + Vector2(offset_x, offset_y)).round()
	background.size = draw_size.round()

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
