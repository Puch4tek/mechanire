@tool
extends Node2D

@export var maze_path: NodePath = NodePath("../Maze")
@export var grid_controller_path: NodePath = NodePath("../GridController")
@export var tile_size: float = 64.0
@export var default_columns: int = 13
@export var default_rows: int = 11
@export var outline_color: Color = Color(0.2, 0.8, 1.0, 0.95)
@export var fill_color: Color = Color(0.2, 0.8, 1.0, 0.12)
@export var line_width: float = 3.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		queue_redraw()
	else:
		visible = false
		set_process(false)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var rect: Rect2 = _get_board_rect()
	draw_rect(rect, fill_color, true)
	draw_rect(rect, outline_color, false, line_width)

func _get_board_rect() -> Rect2:
	var cols: int = max(1, default_columns)
	var rows: int = max(1, default_rows)
	var top_left: Vector2 = Vector2.ZERO

	var maze: Node2D = get_node_or_null(maze_path) as Node2D
	if maze != null:
		top_left = maze.position

	var grid_controller: Node = get_node_or_null(grid_controller_path)
	if grid_controller != null and grid_controller.get("level") != null:
		var level: Variant = grid_controller.get("level")
		if level != null:
			cols = max(1, int(level.width))
			rows = max(1, int(level.height))

	return Rect2(top_left, Vector2(float(cols) * tile_size, float(rows) * tile_size))

