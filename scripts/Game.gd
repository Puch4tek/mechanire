extends Node2D

@export var hud_margin: float = 12.0
@export var dpad_size: Vector2 = Vector2(272.0, 272.0)
@export var dpad_max_scale: float = 1.36
@export var top_button_size: Vector2 = Vector2(88.0, 88.0)
@export var score_size: Vector2 = Vector2(240.0, 34.0)
@export var level_size: Vector2 = Vector2(260.0, 34.0)

@onready var maze: TileMapLayer = $Maze
@onready var grid_controller: Node = $GridController
@onready var score_label: Label = $CanvasLayer/Control/ScoreLabel
@onready var level_label: Label = $CanvasLayer/Control/LevelLabel
@onready var pause_button: Button = $CanvasLayer/Control/PauseButton
@onready var reset_button: Button = $CanvasLayer/Control/ResetButton
@onready var arrow_panel: Control = $CanvasLayer/Control/ArrowPanel
@onready var arrow_up: Control = $CanvasLayer/Control/ArrowPanel/ArrowUp
@onready var arrow_left: Control = $CanvasLayer/Control/ArrowPanel/ArrowLeft
@onready var arrow_right: Control = $CanvasLayer/Control/ArrowPanel/ArrowRight
@onready var arrow_down: Control = $CanvasLayer/Control/ArrowPanel/ArrowDown

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_viewport().size_changed.connect(Callable(self, "_layout_hud"))
	call_deferred("_layout_hud")

func _on_reset_button_pressed() -> void:
	var controller := get_node_or_null("GameController")
	if controller != null and controller.has_method("reset_current_level"):
		controller.reset_current_level()
		return
	# Fallback only if controller method is unavailable.
	get_tree().reload_current_scene()


func _on_pause_button_pressed() -> void:
	get_tree().paused = true
	$CanvasLayer/Pause.visible = true

func _layout_hud() -> void:
	if maze == null:
		return

	var safe_rect: Rect2 = _get_safe_rect()
	var board_rect: Rect2 = _get_board_rect()

	# Labels outside the board: shared X at left of board, stacked from top safe area.
	var labels_x: float = board_rect.position.x - maxf(score_size.x, level_size.x) - hud_margin
	labels_x = clampf(labels_x, safe_rect.position.x + hud_margin, safe_rect.end.x - maxf(score_size.x, level_size.x) - hud_margin)
	var labels_top: float = safe_rect.position.y + hud_margin

	var score_pos: Vector2 = _clamp_rect_top_left(
		Vector2(labels_x, labels_top),
		score_size,
		safe_rect
	)
	_set_control_rect(score_label, score_pos, score_size)

	var level_pos: Vector2 = _clamp_rect_top_left(
		Vector2(labels_x, labels_top + score_size.y + 6.0),
		level_size,
		safe_rect
	)
	_set_control_rect(level_label, level_pos, level_size)

	# Right-side HUD midway between board edge and scene edge.
	var right_mid_x: float = lerpf(board_rect.end.x, safe_rect.end.x, 0.5)
	var top_controls_width: float = top_button_size.x * 2.0 + 8.0
	var top_controls_left: float = right_mid_x - top_controls_width * 0.5

	var pause_pos: Vector2 = _clamp_rect_top_left(
		Vector2(top_controls_left, board_rect.position.y + hud_margin),
		top_button_size,
		safe_rect
	)
	_set_control_rect(pause_button, pause_pos, top_button_size)

	var reset_pos: Vector2 = _clamp_rect_top_left(
		Vector2(top_controls_left + top_button_size.x + 8.0, pause_pos.y),
		top_button_size,
		safe_rect
	)
	_set_control_rect(reset_button, reset_pos, top_button_size)

	# D-pad centered on the same midway column.
	var free_right_width: float = safe_rect.end.x - board_rect.end.x - hud_margin * 2.0
	var dpad_scale: float = 1.0
	if dpad_size.x > 0.0 and dpad_size.y > 0.0:
		# Fill available space aggressively, but cap size so D-pad stays visually balanced.
		var max_by_width: float = free_right_width / dpad_size.x
		var max_by_board_height: float = (board_rect.size.y * 0.48) / dpad_size.y
		var max_by_screen_height: float = (safe_rect.size.y * 0.42) / dpad_size.y
		var allowed_max: float = minf(minf(dpad_max_scale, max_by_width), minf(max_by_board_height, max_by_screen_height))
		dpad_scale = clampf(allowed_max, 0.5, dpad_max_scale)
	var dpad_visual_size: Vector2 = dpad_size * dpad_scale
	var dpad_left: float = right_mid_x - dpad_visual_size.x * 0.5
	var dpad_pos: Vector2 = _clamp_rect_top_left(
		Vector2(dpad_left, board_rect.end.y - dpad_visual_size.y - hud_margin),
		dpad_visual_size,
		safe_rect
	)
	dpad_pos.x = maxf(dpad_pos.x, board_rect.end.x + hud_margin)
	_set_control_rect(arrow_panel, dpad_pos, dpad_visual_size)
	_layout_dpad_buttons(dpad_scale)

func _get_board_rect() -> Rect2:
	var board_width: float = 13.0 * 64.0
	var board_height: float = 11.0 * 64.0
	if grid_controller != null and grid_controller.get("level") != null:
		var level = grid_controller.get("level")
		board_width = float(level.width * 64)
		board_height = float(level.height * 64)
	return Rect2(maze.position, Vector2(board_width, board_height))

func _get_safe_rect() -> Rect2:
	var viewport_rect: Rect2 = get_viewport_rect()
	var safe_rect: Rect2 = viewport_rect
	if DisplayServer.has_method("get_display_safe_area"):
		var ds_safe: Rect2i = DisplayServer.get_display_safe_area()
		if ds_safe.size.x > 0 and ds_safe.size.y > 0:
			var window_size_i: Vector2i = DisplayServer.window_get_size()
			var window_size: Vector2 = Vector2(window_size_i)
			if window_size.x > 0.0 and window_size.y > 0.0:
				# Android may report safe area in physical window pixels.
				var safe_scale: Vector2 = Vector2(
					viewport_rect.size.x / window_size.x,
					viewport_rect.size.y / window_size.y
				)
				safe_rect = Rect2(Vector2(ds_safe.position) * safe_scale, Vector2(ds_safe.size) * safe_scale)
			else:
				safe_rect = Rect2(Vector2(ds_safe.position), Vector2(ds_safe.size))

	# Ensure we never return a rect outside current viewport coordinates.
	safe_rect = safe_rect.intersection(viewport_rect)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		safe_rect = viewport_rect
	return safe_rect

func _clamp_rect_top_left(pos: Vector2, size: Vector2, safe_rect: Rect2) -> Vector2:
	var min_x: float = safe_rect.position.x + hud_margin
	var min_y: float = safe_rect.position.y + hud_margin
	var max_x: float = safe_rect.end.x - size.x - hud_margin
	var max_y: float = safe_rect.end.y - size.y - hud_margin
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))

func _set_control_rect(ctrl: Control, pos: Vector2, size: Vector2) -> void:
	if ctrl == null:
		return
	ctrl.anchor_left = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_right = 0.0
	ctrl.anchor_bottom = 0.0
	ctrl.offset_left = pos.x
	ctrl.offset_top = pos.y
	ctrl.offset_right = pos.x + size.x
	ctrl.offset_bottom = pos.y + size.y

func _layout_dpad_buttons(scale_factor: float) -> void:
	var sx: float = maxf(0.5, scale_factor)
	var sy: float = sx
	_set_control_rect(arrow_up, Vector2(95.0 * sx, 12.0 * sy), Vector2(82.0 * sx, 82.0 * sy))
	_set_control_rect(arrow_left, Vector2(12.0 * sx, 95.0 * sy), Vector2(82.0 * sx, 82.0 * sy))
	_set_control_rect(arrow_right, Vector2(178.0 * sx, 95.0 * sy), Vector2(82.0 * sx, 82.0 * sy))
	_set_control_rect(arrow_down, Vector2(95.0 * sx, 178.0 * sy), Vector2(82.0 * sx, 82.0 * sy))


func _queue_arrow_direction(dir: Vector2i) -> void:
	var controller := get_node_or_null("GameController")
	if controller == null:
		return
	if controller.has_method("queue_direction"):
		controller.queue_direction(dir)

func _on_arrow_up_pressed() -> void:
	_queue_arrow_direction(Vector2i.UP)

func _on_arrow_left_pressed() -> void:
	_queue_arrow_direction(Vector2i.LEFT)

func _on_arrow_right_pressed() -> void:
	_queue_arrow_direction(Vector2i.RIGHT)

func _on_arrow_down_pressed() -> void:
	_queue_arrow_direction(Vector2i.DOWN)
