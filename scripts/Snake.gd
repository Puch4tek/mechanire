extends Node2D

@export var head_texture: Texture2D
@export var body_texture: Texture2D
@export var tail_texture: Texture2D
@export var head_transition_texture: Texture2D
@export var tail_transition_texture: Texture2D
@export var corner_texture: Texture2D
@export var segment_scene: PackedScene
@export var tile_size: int = 64
@export var move_speed_px: float = 220.0
@export var tail_rotation_offset: float = PI

var segments: Array[Node2D] = []
var segment_cells: Array[Vector2i] = []
var previous_segment_cells: Array[Vector2i] = []
var direction: Vector2i = Vector2i.RIGHT
var requested_direction: Vector2i = Vector2i.RIGHT
var head_cell: Vector2i
var maze_offset: Vector2 = Vector2.ZERO
var move_accumulator: float = 0.0

func grid_to_world(cell: Vector2i) -> Vector2:
	return maze_offset + Vector2(
		cell.x * tile_size + tile_size / 2.0,
		cell.y * tile_size + tile_size / 2.0
	)

func _configure_segment(seg: Node2D) -> void:
	if seg.has_method("set_tile_size"):
		seg.set_tile_size(float(tile_size))

func spawn_snake(start: Vector2i, length: int = 3, initial_direction: Vector2i = direction) -> void:
	for seg in segments:
		seg.queue_free()
	segments.clear()
	segment_cells.clear()
	previous_segment_cells.clear()

	if initial_direction == Vector2i.ZERO:
		initial_direction = Vector2i.RIGHT

	direction = initial_direction
	requested_direction = initial_direction
	head_cell = start
	move_accumulator = 0.0

	for i in range(max(1, length)):
		var cell: Vector2i = start - initial_direction * i
		var seg: Node2D = segment_scene.instantiate()
		_configure_segment(seg)
		seg.position = grid_to_world(cell)
		add_child(seg)

		segments.append(seg)
		segment_cells.append(cell)
	previous_segment_cells = segment_cells.duplicate()

	update_positions()

func grow() -> void:
	if segment_cells.is_empty():
		return

	var tail_cell: Vector2i = segment_cells[-1]
	var seg: Node2D = segment_scene.instantiate()
	_configure_segment(seg)
	seg.position = grid_to_world(tail_cell)
	add_child(seg)

	segments.append(seg)
	segment_cells.append(tail_cell)
	previous_segment_cells = segment_cells.duplicate()
	update_positions()

func shrink_tail(count: int = 1, min_length: int = 1) -> int:
	var removed: int = 0
	var safe_min: int = max(1, min_length)
	var to_remove: int = max(0, count)

	while removed < to_remove and segments.size() > safe_min:
		var tail_index: int = segments.size() - 1
		var tail_segment: Node2D = segments[tail_index]
		if is_instance_valid(tail_segment):
			tail_segment.queue_free()

		segments.remove_at(tail_index)
		segment_cells.remove_at(tail_index)
		removed += 1

	if removed > 0:
		previous_segment_cells = segment_cells.duplicate()
		update_positions()
	return removed

func set_direction(new_dir: Vector2i) -> void:
	if new_dir == Vector2i.ZERO:
		return
	requested_direction = new_dir

func can_move_forward(grid_controller, for_dir: Vector2i = direction, ignore_walls: bool = false) -> bool:
	if ignore_walls:
		return grid_controller.is_inside_grid(head_cell + for_dir)
	return grid_controller.can_move(head_cell, for_dir)

func get_effective_direction(grid_controller, ignore_walls: bool = false) -> Vector2i:
	if can_apply_requested_direction(grid_controller, ignore_walls):
		return requested_direction
	return direction

func contains_cell(cell: Vector2i) -> bool:
	return cell in segment_cells

func get_step_duration() -> float:
	return float(tile_size) / maxf(1.0, move_speed_px)

func consume_step_budget(delta: float) -> int:
	if delta <= 0.0:
		return 0
	move_accumulator += delta
	var step_duration: float = get_step_duration()
	var steps: int = int(floor(move_accumulator / step_duration))
	if steps <= 0:
		return 0
	# Limit kroków na jedną klatkę, żeby nie "teleportować" przy spadkach FPS.
	steps = min(steps, 4)
	move_accumulator -= step_duration * float(steps)
	return steps

func advance(grid_controller, ignore_walls: bool = false) -> bool:
	if segment_cells.is_empty():
		return false

	if can_apply_requested_direction(grid_controller, ignore_walls):
		direction = requested_direction

	if not ignore_walls and not grid_controller.can_move(head_cell, direction):
		return false

	previous_segment_cells = segment_cells.duplicate()

	var next_head: Vector2i = head_cell + direction

	for i in range(segment_cells.size() - 1, 0, -1):
		segment_cells[i] = segment_cells[i - 1]
	segment_cells[0] = next_head
	head_cell = next_head

	update_positions()
	return true

func can_apply_requested_direction(grid_controller, ignore_walls: bool = false) -> bool:
	if requested_direction == direction:
		return false

	if ignore_walls:
		return grid_controller.is_inside_grid(head_cell + requested_direction)

	return grid_controller.can_move(head_cell, requested_direction)

func _dir_to_rotation(dir: Vector2i) -> float:
	# Wszystkie tekstury bazowe traktujemy jako "do gory" (UP).
	if dir == Vector2i.UP:
		return 0.0
	if dir == Vector2i.RIGHT:
		return PI * 0.5
	if dir == Vector2i.DOWN:
		return PI
	if dir == Vector2i.LEFT:
		return -PI * 0.5
	return 0.0

func _corner_rotation(dir_a: Vector2i, dir_b: Vector2i) -> float:
	# Bazowa orientacja narożnika: połączenie LEFT + UP.
	var has_right: bool = dir_a == Vector2i.RIGHT or dir_b == Vector2i.RIGHT
	var has_down: bool = dir_a == Vector2i.DOWN or dir_b == Vector2i.DOWN
	var has_left: bool = dir_a == Vector2i.LEFT or dir_b == Vector2i.LEFT
	var has_up: bool = dir_a == Vector2i.UP or dir_b == Vector2i.UP

	if has_left and has_up:
		return 0.0
	if has_up and has_right:
		return PI * 0.5
	if has_right and has_down:
		return PI
	if has_down and has_left:
		return -PI * 0.5
	return 0.0

func _transition_corner_transform(dir_a: Vector2i, dir_b: Vector2i) -> Dictionary:
	# Bazowa orientacja transition PNG: zakret UP + LEFT.
	var has_right: bool = dir_a == Vector2i.RIGHT or dir_b == Vector2i.RIGHT
	var has_down: bool = dir_a == Vector2i.DOWN or dir_b == Vector2i.DOWN
	var has_left: bool = dir_a == Vector2i.LEFT or dir_b == Vector2i.LEFT
	var has_up: bool = dir_a == Vector2i.UP or dir_b == Vector2i.UP

	if has_up and has_left:
		return {"rotation": 0.0, "flip_h": false, "flip_v": false}
	if has_up and has_right:
		return {"rotation": 0.0, "flip_h": true, "flip_v": false}
	if has_down and has_left:
		return {"rotation": PI, "flip_h": true, "flip_v": false}
	if has_down and has_right:
		return {"rotation": PI, "flip_h": false, "flip_v": false}

	return {"rotation": 0.0, "flip_h": false, "flip_v": false}

func _head_transition_corner_transform(dir_a: Vector2i, dir_b: Vector2i) -> Dictionary:
	# Bazowa orientacja head->chest PNG: zakret DOWN + RIGHT (bottom -> right).
	var has_right: bool = dir_a == Vector2i.RIGHT or dir_b == Vector2i.RIGHT
	var has_down: bool = dir_a == Vector2i.DOWN or dir_b == Vector2i.DOWN
	var has_left: bool = dir_a == Vector2i.LEFT or dir_b == Vector2i.LEFT
	var has_up: bool = dir_a == Vector2i.UP or dir_b == Vector2i.UP

	if has_down and has_right:
		return {"rotation": 0.0, "flip_h": false, "flip_v": false}
	if has_down and has_left:
		return {"rotation": PI * 0.5, "flip_h": false, "flip_v": false}
	if has_left and has_up:
		return {"rotation": PI, "flip_h": false, "flip_v": false}
	if has_up and has_right:
		return {"rotation": -PI * 0.5, "flip_h": false, "flip_v": false}

	return {"rotation": 0.0, "flip_h": false, "flip_v": false}

func update_positions() -> void:
	for i in range(segments.size()):
		var segment: Node2D = segments[i]
		segment.position = grid_to_world(segment_cells[i])
		# Segments already moving in the new direction render above lagging segments.
		var base_z: int = segments.size() - i
		var is_active_reverse_wave: bool = false
		if previous_segment_cells.size() == segment_cells.size() and i < previous_segment_cells.size():
			var move_delta: Vector2i = segment_cells[i] - previous_segment_cells[i]
			is_active_reverse_wave = move_delta != Vector2i.ZERO and move_delta == direction
		segment.z_index = base_z + (1000 if is_active_reverse_wave else 0)

		var texture_to_use: Texture2D = body_texture
		var rotation_angle: float = 0.0
		var flip_h: bool = false
		var flip_v: bool = false

		if segments.size() == 1:
			texture_to_use = head_texture if head_texture else body_texture
			rotation_angle = _dir_to_rotation(direction)
		elif i == 0:
			var neck: Vector2i = segment_cells[1]
			var head_dir: Vector2i = segment_cells[0] - neck
			texture_to_use = head_texture if head_texture else body_texture
			rotation_angle = _dir_to_rotation(head_dir)
		elif i == segments.size() - 1:
			var prev: Vector2i = segment_cells[i - 1]
			var tail_dir: Vector2i = segment_cells[i] - prev
			texture_to_use = tail_texture if tail_texture else body_texture
			rotation_angle = _dir_to_rotation(tail_dir) + tail_rotation_offset
		else:
			var prev_cell: Vector2i = segment_cells[i - 1]
			var curr_cell: Vector2i = segment_cells[i]
			var next_cell: Vector2i = segment_cells[i + 1]
			var dir_to_prev: Vector2i = prev_cell - curr_cell
			var dir_to_next: Vector2i = next_cell - curr_cell
			var is_head_bridge: bool = i == 1 and head_transition_texture != null
			var is_tail_bridge: bool = i == segments.size() - 2 and tail_transition_texture != null
			var bridge_texture: Texture2D = null
			if is_head_bridge:
				bridge_texture = head_transition_texture
			elif is_tail_bridge:
				bridge_texture = tail_transition_texture

			if dir_to_prev == -dir_to_next:
				# Na prostych odcinkach zawsze zwykle "chest" (body), bez transition.
				texture_to_use = body_texture
				rotation_angle = _dir_to_rotation(dir_to_prev)
			else:
				if bridge_texture:
					texture_to_use = bridge_texture
					var corner_transform: Dictionary
					if is_head_bridge:
						corner_transform = _head_transition_corner_transform(dir_to_prev, dir_to_next)
					else:
						corner_transform = _transition_corner_transform(dir_to_prev, dir_to_next)
					rotation_angle = corner_transform.get("rotation", 0.0)
					flip_h = corner_transform.get("flip_h", false)
					flip_v = corner_transform.get("flip_v", false)
				else:
					texture_to_use = corner_texture if corner_texture else body_texture
					rotation_angle = _corner_rotation(dir_to_prev, dir_to_next)

		segment.set_visual(texture_to_use, rotation_angle, flip_h, flip_v)
