extends Node

@export var player_speed_px: float = 260.0
@export var enemy_speed_px: float = 150.0
@export var enemy_direction_interval: float = 0.18
@export var enemy_length: int = 3
@export var enemies_per_level: int = 3
@export var enemy_spawn_head_cell: Vector2i = Vector2i(0, 8)
@export var enemy_spawn_direction: Vector2i = Vector2i.UP
@export var enemy_release_interval: float = 0.75
@export var enemy_scene: PackedScene = preload("res://scenes/Snake.tscn")
@export var enemy_head_texture: Texture2D
@export var enemy_body_texture: Texture2D
@export var enemy_tail_texture: Texture2D
@export var enemy_head_transition_texture: Texture2D
@export var enemy_tail_transition_texture: Texture2D
@export var enemy_corner_texture: Texture2D
@export var enemy_texture_folder: String = "res://assets/sobczi"
@export var player_head_texture: Texture2D
@export var player_body_texture: Texture2D
@export var player_tail_texture: Texture2D
@export var player_head_transition_texture: Texture2D
@export var player_tail_transition_texture: Texture2D
@export var player_corner_texture: Texture2D
@export var player_texture_folder: String = "res://assets/golona"
@export var extension_scene: PackedScene = preload("res://scenes/Extension.tscn")
@export var pickup_sfx: AudioStream = preload("res://assets/Pickup.wav")
@export var eat_segment_sfx: AudioStream = preload("res://assets/Hit1.wav")
@export var swipe_min_distance: float = 48.0
@export var level_paths: Array[String] = [
	"res://resources/level1.tres",
	"res://resources/level2.tres",
	"res://resources/level3.tres",
	"res://resources/level4.tres",
	"res://resources/level5.tres",
	"res://resources/level6.tres",
	"res://resources/level7.tres",
	"res://resources/level8.tres",
	"res://resources/level9.tres",
	"res://resources/level10.tres",
]
@export var enemy_attack_score: float = 1000.0
@export var enemy_chase_weight: float = 6.0
@export var enemy_space_weight: float = 2.5
@export var enemy_random_weight: float = 0.55
@export var enemy_objective_commit_time: float = 1.0
@export var player_auto_turn_delay: float = 0.2

const CARDINAL_DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
const ENEMY_RING_OFFSETS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(2, 0),
	Vector2i(-2, 0),
	Vector2i(0, 2),
	Vector2i(0, -2),
]

@onready var grid_controller: Node = get_node("../GridController")
@onready var snake: Node2D = get_node("../Snake")
@onready var game_over_ui: Control = get_node("../CanvasLayer/GameOver")
@onready var game_over_backdrop: Control = get_node_or_null("../CanvasLayer/GameOver/ColorRect")
@onready var score_label: Label = get_node_or_null("../CanvasLayer/Control/ScoreLabel")
@onready var level_label: Label = get_node_or_null("../CanvasLayer/Control/LevelLabel")
@onready var level_complete_ui: Control = get_node_or_null("../CanvasLayer/LevelComplete")
@onready var next_level_button: Button = get_node_or_null("../CanvasLayer/LevelComplete/Panel/VBoxContainer/NextLevelButton")

var enemy_direction_timer: float = 0.0
var queued_direction: Vector2i = Vector2i.RIGHT
var is_running: bool = false
var enemy_snakes: Array[Node2D] = []
var extensions: Array[Node2D] = [] 
var score: int = 0
var active_swipe_index: int = -1
var swipe_start_position: Vector2 = Vector2.ZERO
var current_level_index: int = 0
var level_started_with_enemies: bool = false
var pending_enemy_spawn_data: Array[Dictionary] = []
var enemy_release_timer: float = 0.0
var enemy_moved_this_frame: Dictionary = {}
var enemy_ai_time: float = 0.0
var enemy_objective_until_by_id: Dictionary = {}
var enemy_objective_by_id: Dictionary = {}
var player_wall_block_time: float = 0.0
var player_wall_block_dir: Vector2i = Vector2i.ZERO
var player_wall_block_cell: Vector2i = Vector2i(-1, -1)
var pickup_sfx_player: AudioStreamPlayer
var eat_segment_sfx_player: AudioStreamPlayer

enum GameState {
	RUNNING,
	GAME_OVER,
	LEVEL_CLEAR,
}

var state: GameState = GameState.RUNNING

func _ready() -> void:
	await get_tree().process_frame
	setup_audio_players()
	if next_level_button and not next_level_button.pressed.is_connected(_on_next_level_button_pressed):
		next_level_button.pressed.connect(_on_next_level_button_pressed)
	apply_player_texture_defaults()
	apply_enemy_texture_defaults()
	start_campaign()

func setup_audio_players() -> void:
	pickup_sfx_player = AudioStreamPlayer.new()
	eat_segment_sfx_player = AudioStreamPlayer.new()
	add_child(pickup_sfx_player)
	add_child(eat_segment_sfx_player)
	pickup_sfx_player.stream = pickup_sfx
	eat_segment_sfx_player.stream = eat_segment_sfx

func play_pickup_sfx() -> void:
	if pickup_sfx_player and pickup_sfx_player.stream:
		pickup_sfx_player.play()

func play_eat_segment_sfx() -> void:
	if eat_segment_sfx_player and eat_segment_sfx_player.stream:
		eat_segment_sfx_player.play()

func apply_player_texture_defaults() -> void:
	if player_head_texture == null:
		player_head_texture = load_texture_from_folder(player_texture_folder, "playerHead.png")
	if player_body_texture == null:
		player_body_texture = load_texture_from_folder(player_texture_folder, "playerChest.png")
	if player_tail_texture == null:
		player_tail_texture = load_texture_from_folder(player_texture_folder, "playerLegs.png")
	if player_head_transition_texture == null:
		# Nazwa pliku w assets ma literowke: Transistion.
		player_head_transition_texture = load_texture_from_folder(player_texture_folder, "playerHeadTransition.PNG")
	if player_tail_transition_texture == null:
		player_tail_transition_texture = load_texture_from_folder(player_texture_folder, "playerLegTransition.PNG")
	if player_corner_texture == null:
		player_corner_texture = load_texture_from_folder(player_texture_folder, "playerChestTransition.PNG")
		if player_corner_texture == null:
			player_corner_texture = player_body_texture

func apply_enemy_texture_defaults() -> void:
	if enemy_head_texture == null:
		enemy_head_texture = load_texture_from_folder(enemy_texture_folder, "enemyHead.png")
	if enemy_body_texture == null:
		enemy_body_texture = load_texture_from_folder(enemy_texture_folder, "enemyChest.png")
	if enemy_tail_texture == null:
		enemy_tail_texture = load_texture_from_folder(enemy_texture_folder, "enemyLegs.png")
	if enemy_head_transition_texture == null:
		enemy_head_transition_texture = load_texture_from_folder(enemy_texture_folder, "enemyHeadTransition.png")
	if enemy_tail_transition_texture == null:
		enemy_tail_transition_texture = load_texture_from_folder(enemy_texture_folder, "enemyLegTransition.png")
	if enemy_corner_texture == null:
		enemy_corner_texture = load_texture_from_folder(enemy_texture_folder, "enemyChestTransition.png")
		if enemy_corner_texture == null:
			enemy_corner_texture = enemy_body_texture

func load_texture_from_folder(folder_path: String, file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null
	var base_path: String = folder_path.strip_edges()
	if base_path.is_empty():
		return null
	if base_path.ends_with("/"):
		base_path = base_path.trim_suffix("/")
	var texture_path: String = "%s/%s" % [base_path, file_name]
	if not ResourceLoader.exists(texture_path):
		return null
	var resource: Resource = load(texture_path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func start_campaign() -> void:
	score = 0
	current_level_index = 0
	update_score_label()
	update_level_label()
	if not load_level_by_index(current_level_index):
		trigger_game_over()

func start_game() -> void:
	# Backward-compatible alias for UI hooks that call start_game().
	start_campaign()

func load_level_by_index(index: int) -> bool:
	if level_paths.is_empty():
		push_error("No level paths configured in GameController")
		return false
	if index < 0 or index >= level_paths.size():
		return false

	current_level_index = index
	update_level_label()
	if not grid_controller.load_and_build(level_paths[index]):
		push_error("Could not load level path: %s" % level_paths[index])
		return false

	start_level()
	return true

func start_level() -> void:
	clear_enemy_snakes()
	clear_extensions()
	enemy_ai_time = 0.0
	enemy_objective_until_by_id.clear()
	enemy_objective_by_id.clear()
	reset_player_wall_block_state()

	snake.maze_offset = grid_controller.get_maze_offset()
	snake.tile_size = 64
	snake.move_speed_px = player_speed_px
	snake.head_texture = player_head_texture if player_head_texture else snake.head_texture
	snake.body_texture = player_body_texture if player_body_texture else snake.body_texture
	snake.tail_texture = player_tail_texture if player_tail_texture else snake.body_texture
	snake.head_transition_texture = player_head_transition_texture if player_head_transition_texture else snake.body_texture
	snake.tail_transition_texture = player_tail_transition_texture if player_tail_transition_texture else snake.body_texture
	snake.corner_texture = player_corner_texture if player_corner_texture else snake.body_texture

	var player_spawn_box: Vector2i = grid_controller.level.player_spawn_box
	var player_spawn_dir: Vector2i = grid_controller.level.player_spawn_direction
	if player_spawn_box != Vector2i(-1, -1) and player_spawn_dir != Vector2i.ZERO:
		snake.spawn_snake(player_spawn_box, 3, player_spawn_dir)
	else:
		snake.spawn_snake(grid_controller.get_snake_spawn(), 3)

	queued_direction = pick_player_initial_direction()
	snake.set_direction(queued_direction)

	spawn_enemy_snakes()
	level_started_with_enemies = enemy_snakes.size() > 0 or pending_enemy_spawn_data.size() > 0
	spawn_extension()

	enemy_direction_timer = 0.0
	is_running = true
	state = GameState.RUNNING
	update_score_label()

	if game_over_ui:
		game_over_ui.mouse_filter = Control.MOUSE_FILTER_PASS
		game_over_ui.visible = false
	if game_over_backdrop:
		game_over_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if level_complete_ui:
		level_complete_ui.visible = false

func _process(delta: float) -> void:
	if not is_running or state != GameState.RUNNING:
		return
	enemy_ai_time += delta

	run_player_frame(delta)
	if not is_running:
		return

	update_enemy_release(delta)

	enemy_direction_timer += delta
	if enemy_direction_timer >= enemy_direction_interval:
		enemy_direction_timer -= enemy_direction_interval
		update_enemy_directions()

	run_enemy_frame(delta)
	check_level_clear_condition()

func check_level_clear_condition() -> void:
	if state != GameState.RUNNING:
		return


	if level_started_with_enemies and enemy_snakes.is_empty() and pending_enemy_spawn_data.is_empty():
		trigger_level_clear()

func trigger_level_clear() -> void:
	if state != GameState.RUNNING:
		return

	state = GameState.LEVEL_CLEAR
	is_running = false
	if level_complete_ui:
		level_complete_ui.visible = true
		return

	# Fallback if overlay is missing.
	go_to_next_level()

func _on_next_level_button_pressed() -> void:
	if state != GameState.LEVEL_CLEAR:
		return
	if level_complete_ui:
		level_complete_ui.visible = false
	go_to_next_level()

func go_to_next_level() -> void:
	var next_level: int = current_level_index + 1
	if next_level >= level_paths.size():
		start_campaign()
		return

	if not load_level_by_index(next_level):
		trigger_game_over()

func reset_current_level() -> void:
	if current_level_index < 0 or current_level_index >= level_paths.size():
		if not load_level_by_index(0):
			trigger_game_over()
		return
	if not load_level_by_index(current_level_index):
		trigger_game_over()

func run_player_frame(delta: float) -> void:
	ensure_player_continuous_direction(delta)
	snake.set_direction(queued_direction)
	var steps: int = snake.consume_step_budget(delta)
	for _i in range(steps):
		if not try_advance_snake(snake):
			trigger_game_over()
			return
		consume_extension_at_cell(snake.head_cell, snake, true)

func ensure_player_continuous_direction(delta: float) -> void:
	var effective_dir: Vector2i = snake.get_effective_direction(grid_controller)
	if effective_dir == Vector2i.ZERO:
		reset_player_wall_block_state()
		return
	if grid_controller.can_move(snake.head_cell, effective_dir):
		reset_player_wall_block_state()
		return

	if player_wall_block_cell != snake.head_cell or player_wall_block_dir != effective_dir:
		player_wall_block_cell = snake.head_cell
		player_wall_block_dir = effective_dir
		player_wall_block_time = 0.0

	player_wall_block_time += delta
	if player_wall_block_time < player_auto_turn_delay:
		return

	var fallback_dir: Vector2i = choose_player_wall_turn(effective_dir)
	if fallback_dir == Vector2i.ZERO:
		return

	# Przy bloku na ścianie wymuś automatyczny skręt, żeby ruch był ciągły.
	queued_direction = fallback_dir
	reset_player_wall_block_state()

func reset_player_wall_block_state() -> void:
	player_wall_block_time = 0.0
	player_wall_block_dir = Vector2i.ZERO
	player_wall_block_cell = Vector2i(-1, -1)

func choose_player_wall_turn(blocked_dir: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = [turn_left(blocked_dir), turn_right(blocked_dir)]
	var available_turns: Array[Vector2i] = []
	for dir in candidates:
		if grid_controller.can_move(snake.head_cell, dir):
			available_turns.append(dir)

	if available_turns.is_empty():
		return Vector2i.ZERO
	if available_turns.size() == 1:
		return available_turns[0]
	return available_turns.pick_random()

func run_enemy_frame(delta: float) -> void:
	enemy_moved_this_frame.clear()
	for idx in range(enemy_snakes.size() - 1, -1, -1):
		var enemy: Node2D = enemy_snakes[idx]
		if not is_instance_valid(enemy):
			enemy_snakes.remove_at(idx)
			continue
		if enemy_moved_this_frame.has(enemy):
			continue

		if not is_enemy_runtime_valid(enemy):
			enemy.queue_free()
			enemy_snakes.remove_at(idx)
			continue

		var steps: int = enemy.consume_step_budget(delta)
		for _i in range(steps):
			if not try_advance_snake(enemy):
				# Blocked/collision step: keep enemy alive, try another direction on next tick.
				var recovery_dir: Vector2i = choose_enemy_direction(enemy)
				if recovery_dir == Vector2i.ZERO:
					recovery_dir = choose_enemy_nonblocking_direction(enemy)
				if recovery_dir != Vector2i.ZERO:
					enemy.set_direction(recovery_dir)
				break
			consume_extension_at_cell(enemy.head_cell, enemy, false)
		if not is_running:
			enemy.queue_free()
			enemy_snakes.remove_at(idx)

func update_enemy_directions() -> void:
	cleanup_enemy_objective_cache()
	var reservation: Dictionary = {}
	var update_order: Array[Node2D] = enemy_snakes.duplicate()
	update_order.shuffle()
	for enemy in update_order:
		if not is_instance_valid(enemy):
			continue
		var enemy_index: int = enemy_snakes.find(enemy)
		var chosen_dir: Vector2i = choose_enemy_direction(enemy, reservation, enemy_index)
		if chosen_dir == Vector2i.ZERO:
			chosen_dir = choose_enemy_nonblocking_direction(enemy, reservation)
		if chosen_dir == Vector2i.ZERO:
			chosen_dir = enemy.direction
		enemy.set_direction(chosen_dir)
		var reserved_head: Vector2i = enemy.head_cell + chosen_dir
		if chosen_dir != Vector2i.ZERO and grid_controller.can_move(enemy.head_cell, chosen_dir):
			reservation[reserved_head] = true

func spawn_enemy_snakes() -> void:
	pending_enemy_spawn_data.clear()
	enemy_release_timer = 0.0

	var desired_count: int = max(1, enemies_per_level)
	for _i in range(desired_count):
		pending_enemy_spawn_data.append({
			"spawn": enemy_spawn_head_cell,
			"initial_direction": enemy_spawn_direction if enemy_spawn_direction != Vector2i.ZERO else Vector2i.UP,
		})

	# Spawn first enemy immediately, the rest come out one by one.
	spawn_next_enemy_from_queue()

func update_enemy_release(delta: float) -> void:
	if pending_enemy_spawn_data.is_empty():
		return

	enemy_release_timer -= delta
	if enemy_release_timer > 0.0:
		return

	if spawn_next_enemy_from_queue():
		enemy_release_timer = enemy_release_interval
	else:
		# Retry shortly if spawn slot is temporarily blocked.
		enemy_release_timer = 0.2

func spawn_next_enemy_from_queue() -> bool:
	if pending_enemy_spawn_data.is_empty():
		return false

	var candidate: Dictionary = pending_enemy_spawn_data[0]
	if not is_enemy_spawn_valid(candidate):
		return false

	pending_enemy_spawn_data.remove_at(0)

	var spawn: Vector2i = candidate.get("spawn", Vector2i.ZERO)
	var initial_direction: Vector2i = candidate.get("initial_direction", Vector2i.UP)

	var enemy: Node2D = enemy_scene.instantiate()
	enemy.head_texture = enemy_head_texture if enemy_head_texture else snake.head_texture
	enemy.body_texture = enemy_body_texture if enemy_body_texture else snake.body_texture
	enemy.tail_texture = enemy_tail_texture if enemy_tail_texture else enemy.body_texture
	enemy.head_transition_texture = enemy_head_transition_texture if enemy_head_transition_texture else enemy.body_texture
	enemy.tail_transition_texture = enemy_tail_transition_texture if enemy_tail_transition_texture else enemy.body_texture
	enemy.corner_texture = enemy_corner_texture if enemy_corner_texture else enemy.body_texture
	enemy.segment_scene = snake.segment_scene
	enemy.maze_offset = grid_controller.get_maze_offset()
	enemy.tile_size = snake.tile_size
	enemy.move_speed_px = enemy_speed_px

	get_parent().add_child(enemy)
	enemy.spawn_snake(spawn, enemy_length, initial_direction)
	enemy_snakes.append(enemy)
	return true

func clear_enemy_snakes() -> void:
	for enemy in enemy_snakes:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemy_snakes.clear()
	enemy_objective_until_by_id.clear()
	enemy_objective_by_id.clear()

func clear_extensions() -> void:
	for ext in extensions:
		if is_instance_valid(ext):
			ext.queue_free()
	extensions.clear()

func pick_player_initial_direction() -> Vector2i:
	var candidates: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, -1), Vector2i(0, 1)]
	for dir in candidates:
		if snake.can_move_forward(grid_controller, dir):
			return dir
	return Vector2i.RIGHT

func is_enemy_spawn_valid(spawn_data: Dictionary) -> bool:
	var spawn: Vector2i = spawn_data.get("spawn", Vector2i.ZERO)
	var initial_direction: Vector2i = spawn_data.get("initial_direction", Vector2i.RIGHT)
	var safe_dir: Vector2i = initial_direction if initial_direction != Vector2i.ZERO else Vector2i.RIGHT

	if spawn == snake.head_cell:
		return false

	for i in range(enemy_length):
		var body_cell: Vector2i = spawn - safe_dir * i
		if not grid_controller.is_inside_grid(body_cell):
			return false
		if snake.contains_cell(body_cell):
			return false
		for enemy in enemy_snakes:
			if is_instance_valid(enemy) and enemy.contains_cell(body_cell):
				return false

	return true

func is_enemy_runtime_valid(enemy: Node2D) -> bool:
	if enemy.segment_cells.is_empty():
		return false

	for cell in enemy.segment_cells:
		if not grid_controller.is_inside_grid(cell):
			return false

	return true

func choose_enemy_direction(enemy: Node2D, reserved_heads: Dictionary = {}, enemy_index: int = -1) -> Vector2i:
	var current: Vector2i = enemy.direction
	var candidates: Array[Vector2i] = [current, turn_left(current), turn_right(current), -current]
	var best_direction: Vector2i = Vector2i.ZERO
	var best_score: float = -INF
	if enemy_index < 0:
		enemy_index = enemy_snakes.find(enemy)

	for dir in candidates:
		if not grid_controller.can_move(enemy.head_cell, dir):
			continue
		var next_head: Vector2i = enemy.head_cell + dir
		if reserved_heads.has(next_head):
			continue
		if snake_would_collide(enemy, dir):
			continue

		var direction_score: float = score_enemy_direction(enemy, dir, enemy_index)
		if direction_score > best_score:
			best_score = direction_score
			best_direction = dir

	return best_direction

func choose_enemy_nonblocking_direction(enemy: Node2D, reserved_heads: Dictionary = {}) -> Vector2i:
	var current: Vector2i = enemy.direction
	var candidates: Array[Vector2i] = [current, turn_left(current), turn_right(current), -current]
	for dir in candidates:
		if dir == Vector2i.ZERO:
			continue
		if not grid_controller.can_move(enemy.head_cell, dir):
			continue
		var next_head: Vector2i = enemy.head_cell + dir
		if reserved_heads.has(next_head):
			continue
		if enemy_hits_other_enemy(enemy, next_head):
			continue
		if enemy.contains_cell(next_head):
			continue
		return dir
	return Vector2i.ZERO

func score_enemy_direction(enemy: Node2D, dir: Vector2i, enemy_index: int) -> float:
	var next_head: Vector2i = enemy.head_cell + dir
	var direction_score: float = randf_range(-enemy_random_weight, enemy_random_weight)
	var objective: Dictionary = get_enemy_objective(enemy, enemy_index)
	var chasing_player: bool = objective.get("chasing_player", true)
	var target_cell: Vector2i = objective.get("target_cell", snake.head_cell)

	if chasing_player:
		if snake.contains_cell(next_head):
			direction_score += enemy_attack_score
		var player_dist_now: int = manhattan(enemy.head_cell, snake.head_cell)
		var player_dist_next: int = manhattan(next_head, snake.head_cell)
		direction_score += float(player_dist_now - player_dist_next) * enemy_chase_weight * 0.8
	else:
		var ext_dist_now: int = manhattan(enemy.head_cell, target_cell)
		var ext_dist_next: int = manhattan(next_head, target_cell)
		direction_score += float(ext_dist_now - ext_dist_next) * enemy_chase_weight * 0.9

		# Jeśli extension jest celem, niech wróg delikatnie unika frontalnego zderzenia z graczem.
		if snake.contains_cell(next_head):
			direction_score -= enemy_attack_score * 0.5

	var open_paths: int = count_open_paths(next_head)
	direction_score += float(open_paths) * enemy_space_weight
	direction_score += enemy_separation_score(enemy, next_head, dir)

	if dir == enemy.direction:
		direction_score += 0.25

	return direction_score

func get_enemy_objective(enemy: Node2D, enemy_index: int) -> Dictionary:
	var enemy_id: int = get_enemy_id(enemy)
	if enemy_objective_until_by_id.has(enemy_id) and enemy_objective_by_id.has(enemy_id):
		var commit_until: float = float(enemy_objective_until_by_id[enemy_id])
		if enemy_ai_time <= commit_until:
			var committed: Dictionary = enemy_objective_by_id[enemy_id]
			if bool(committed.get("chasing_player", true)):
				return {
					"chasing_player": true,
					"target_cell": get_player_target_cell(enemy_index),
				}
			var committed_cell: Vector2i = committed.get("target_cell", Vector2i(-1, -1))
			if is_extension_cell_available(committed_cell):
				return committed

	var nearest_extension_cell: Vector2i = get_nearest_extension_cell(enemy)
	var has_extension_target: bool = nearest_extension_cell != Vector2i(-1, -1)
	if not has_extension_target:
		var player_objective := {
			"chasing_player": true,
			"target_cell": get_player_target_cell(enemy_index),
		}
		enemy_objective_by_id[enemy_id] = player_objective
		enemy_objective_until_by_id[enemy_id] = enemy_ai_time + enemy_objective_commit_time
		return player_objective

	var extension_dist: int = manhattan(enemy.head_cell, nearest_extension_cell)
	var player_dist: int = manhattan(enemy.head_cell, snake.head_cell)
	if extension_dist < player_dist:
		var extension_objective := {
			"chasing_player": false,
			"target_cell": nearest_extension_cell,
		}
		enemy_objective_by_id[enemy_id] = extension_objective
		enemy_objective_until_by_id[enemy_id] = enemy_ai_time + enemy_objective_commit_time
		return extension_objective

	var fallback_player_objective := {
		"chasing_player": true,
		"target_cell": get_player_target_cell(enemy_index),
	}
	enemy_objective_by_id[enemy_id] = fallback_player_objective
	enemy_objective_until_by_id[enemy_id] = enemy_ai_time + enemy_objective_commit_time
	return fallback_player_objective

func get_nearest_extension_cell(enemy: Node2D) -> Vector2i:
	var nearest_cell: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 1 << 30
	for ext in extensions:
		if not is_instance_valid(ext):
			continue
		var ext_cell_value: Variant = ext.get("cell")
		if typeof(ext_cell_value) != TYPE_VECTOR2I:
			continue
		var ext_cell: Vector2i = ext_cell_value
		var d: int = manhattan(enemy.head_cell, ext_cell)
		if d < best_dist:
			best_dist = d
			nearest_cell = ext_cell
	return nearest_cell

func get_player_target_cell(enemy_index: int) -> Vector2i:
	if ENEMY_RING_OFFSETS.is_empty() or enemy_index < 0:
		return snake.head_cell
	var offset: Vector2i = ENEMY_RING_OFFSETS[enemy_index % ENEMY_RING_OFFSETS.size()]
	var candidate: Vector2i = snake.head_cell + offset
	if grid_controller.is_inside_grid(candidate):
		return candidate
	return snake.head_cell

func is_extension_cell_available(cell: Vector2i) -> bool:
	if cell == Vector2i(-1, -1):
		return false
	for ext in extensions:
		if not is_instance_valid(ext):
			continue
		if ext.cell == cell:
			return true
	return false

func get_enemy_id(enemy: Node2D) -> int:
	if enemy == null:
		return -1
	return enemy.get_instance_id()

func cleanup_enemy_objective_cache() -> void:
	var alive_ids: Dictionary = {}
	for enemy in enemy_snakes:
		if not is_instance_valid(enemy):
			continue
		alive_ids[get_enemy_id(enemy)] = true

	for key in enemy_objective_by_id.keys():
		if not alive_ids.has(key):
			enemy_objective_by_id.erase(key)
	for key in enemy_objective_until_by_id.keys():
		if not alive_ids.has(key):
			enemy_objective_until_by_id.erase(key)

func enemy_separation_score(enemy: Node2D, next_head: Vector2i, dir: Vector2i) -> float:
	var separation_score: float = 0.0
	for other in enemy_snakes:
		if not is_instance_valid(other) or other == enemy:
			continue

		var dist: int = manhattan(next_head, other.head_cell)
		if dist == 0:
			separation_score -= 100.0
		elif dist == 1:
			separation_score -= 0.8

		# Penalize queueing directly behind another enemy in the same direction.
		if other.direction == dir and next_head == other.head_cell - dir:
			separation_score -= 1.6

	return separation_score

func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func count_open_paths(cell: Vector2i) -> int:
	var count: int = 0
	for dir in CARDINAL_DIRS:
		if grid_controller.can_move(cell, dir):
			count += 1
	return count

func turn_left(dir: Vector2i) -> Vector2i:
	return Vector2i(dir.y, -dir.x)

func turn_right(dir: Vector2i) -> Vector2i:
	return Vector2i(-dir.y, dir.x)

func try_advance_snake(moving_snake: Node2D) -> bool:
	var effective_dir: Vector2i = moving_snake.get_effective_direction(grid_controller)
	if not grid_controller.can_move(moving_snake.head_cell, effective_dir):
		return true

	var next_head_cell: Vector2i = moving_snake.head_cell + effective_dir
	if moving_snake != snake and try_resolve_enemy_head_swap(moving_snake, next_head_cell, effective_dir):
		return true
	if moving_snake != snake and enemy_hits_other_enemy(moving_snake, next_head_cell):
		return false

	# Gracz moze zjesc glowe enemy od tylu (nie ginie przy takim kontakcie).
	if try_consume_enemy_head_from_behind(moving_snake, next_head_cell, effective_dir):
		moving_snake.advance(grid_controller)
		return true
	# Enemy moze zjesc glowe gracza od tylu.
	if try_consume_player_head_from_behind(moving_snake, next_head_cell, effective_dir):
		moving_snake.advance(grid_controller)
		return true
	# Dluższy wąż może zjeść krótszego od przodu (gracz <-> enemy).
	if try_consume_shorter_head_from_front(moving_snake, next_head_cell, effective_dir):
		moving_snake.advance(grid_controller)
		return true

	# Rear-end ma pierwszeństwo nad zwykłą kolizją.
	var rear_target: Node2D = find_rear_end_target_grid(moving_snake, next_head_cell, effective_dir)
	if rear_target != null:
		if not consume_tail_target(moving_snake, rear_target):
			return false
		moving_snake.advance(grid_controller)
		return true

	if check_head_collision(moving_snake, next_head_cell):
		return false

	moving_snake.advance(grid_controller)
	return true

func try_consume_enemy_head_from_behind(moving_snake: Node2D, next_head_cell: Vector2i, moving_direction: Vector2i) -> bool:
	if moving_snake != snake:
		return false

	for enemy in enemy_snakes:
		if not is_instance_valid(enemy):
			continue
		if enemy.head_cell != next_head_cell:
			continue

		var enemy_forward: Vector2i = enemy.get_effective_direction(grid_controller)
		if enemy_forward == Vector2i.ZERO:
			enemy_forward = enemy.direction

		var expected_from_cell: Vector2i = enemy.head_cell - enemy_forward
		if moving_snake.head_cell != expected_from_cell:
			continue
		if moving_direction != enemy_forward:
			continue

		eliminate_snake(enemy)
		moving_snake.grow()
		score += 1
		update_score_label()
		return true

	return false

func try_consume_player_head_from_behind(moving_snake: Node2D, next_head_cell: Vector2i, moving_direction: Vector2i) -> bool:
	if moving_snake == snake:
		return false
	if snake.head_cell != next_head_cell:
		return false

	var player_forward: Vector2i = snake.get_effective_direction(grid_controller)
	if player_forward == Vector2i.ZERO:
		player_forward = snake.direction

	var expected_from_cell: Vector2i = snake.head_cell - player_forward
	if moving_snake.head_cell != expected_from_cell:
		return false
	if moving_direction != player_forward:
		return false

	eliminate_snake(snake)
	moving_snake.grow()
	return true

func try_consume_shorter_head_from_front(moving_snake: Node2D, next_head_cell: Vector2i, moving_direction: Vector2i) -> bool:
	if moving_snake == null:
		return false

	if moving_snake == snake:
		for enemy in enemy_snakes:
			if not is_instance_valid(enemy):
				continue
			if _can_consume_from_front(moving_snake, enemy, next_head_cell, moving_direction):
				eliminate_snake(enemy)
				moving_snake.grow()
				score += 1
				update_score_label()
				return true
		return false

	# Enemy może konsumować od przodu tylko gracza, nigdy innego enemy.
	if _can_consume_from_front(moving_snake, snake, next_head_cell, moving_direction):
		eliminate_snake(snake)
		moving_snake.grow()
		return true

	return false

func _can_consume_from_front(attacker: Node2D, target: Node2D, next_head_cell: Vector2i, attacker_dir: Vector2i) -> bool:
	if attacker == null or target == null:
		return false
	if attacker == target:
		return false
	if target.head_cell != next_head_cell:
		return false

	# Tylko dłuższy wąż zjada krótszego od przodu.
	if attacker.segment_cells.size() <= target.segment_cells.size():
		return false

	var target_forward: Vector2i = target.get_effective_direction(grid_controller)
	if target_forward == Vector2i.ZERO:
		target_forward = target.direction
	if target_forward == Vector2i.ZERO:
		return false

	# Kontakt od przodu: atakujący nadjeżdża z pola przed głową ofiary
	# i porusza się przeciwnie do jej kierunku.
	var front_cell: Vector2i = target.head_cell + target_forward
	if attacker.head_cell != front_cell:
		return false
	if attacker_dir != -target_forward:
		return false

	return true

func check_head_collision(moving_snake: Node2D, head_cell: Vector2i) -> bool:
	# W tej wersji gracz może przejechać po własnym ciele (jak w poprzednim zachowaniu projektu).
	if moving_snake != snake and snake.contains_cell(head_cell):
		return true

	# Enemy nie zabijaja sie nawzajem.
	if moving_snake == snake:
		for enemy in enemy_snakes:
			if not is_instance_valid(enemy):
				continue
			if enemy.contains_cell(head_cell):
				return true

	return false

func is_rear_end_contact_grid(
	moving_snake: Node2D,
	target_snake: Node2D,
	next_head_cell: Vector2i,
	moving_direction: Vector2i = Vector2i.ZERO
) -> bool:
	if target_snake == moving_snake:
		return false
	if target_snake.segment_cells.is_empty():
		return false

	var tail_cell: Vector2i = target_snake.segment_cells[-1]
	if tail_cell != next_head_cell:
		return false

	var tail_prev_cell: Vector2i = tail_cell - target_snake.direction
	if target_snake.segment_cells.size() >= 2:
		tail_prev_cell = target_snake.segment_cells[-2]

	# Kierunek "do przodu" ofiary na ogonie: od ogona do poprzedniego segmentu.
	var tail_direction: Vector2i = tail_prev_cell - tail_cell
	var attacker_dir: Vector2i = moving_direction if moving_direction != Vector2i.ZERO else moving_snake.direction
	return Vector2(tail_direction).dot(Vector2(attacker_dir)) > 0

func consume_tail_target(moving_snake: Node2D, target: Node2D) -> bool:
	if target.segment_cells.size() <= 1:
		eliminate_snake(target)
	else:
		if target.shrink_tail(1, 1) <= 0:
			return false
		play_eat_segment_sfx()

	moving_snake.grow()
	if moving_snake == snake:
		score += 1
		update_score_label()
	return true

func find_rear_end_target_grid(
	moving_snake: Node2D,
	next_head_cell: Vector2i,
	moving_direction: Vector2i = Vector2i.ZERO
) -> Node2D:
	if moving_snake != snake and is_rear_end_contact_grid(moving_snake, snake, next_head_cell, moving_direction):
		return snake
	if moving_snake != snake:
		# Enemy can only consume the player, never other enemies.
		return null

	for enemy in enemy_snakes:
		if not is_instance_valid(enemy):
			continue
		# Dla gracza: ogon enemy mozna zjesc rowniez z boku (zeby dzialalo na zakretach).
		if moving_snake == snake and not enemy.segment_cells.is_empty() and enemy.segment_cells[-1] == next_head_cell:
			return enemy
		if is_rear_end_contact_grid(moving_snake, enemy, next_head_cell, moving_direction):
			return enemy

	return null

func snake_would_collide(enemy: Node2D, dir: Vector2i) -> bool:
	var next_head: Vector2i = enemy.head_cell + dir
	if enemy.contains_cell(next_head):
		return true
	if snake.contains_cell(next_head) and not is_rear_end_contact_grid(enemy, snake, next_head, dir):
		return true
	if enemy_hits_other_enemy(enemy, next_head) and not can_enemy_swap_heads(enemy, next_head):
		return true
	return false

func enemy_hits_other_enemy(moving_enemy: Node2D, next_head_cell: Vector2i) -> bool:
	for other_enemy in enemy_snakes:
		if not is_instance_valid(other_enemy) or other_enemy == moving_enemy:
			continue
		if other_enemy.contains_cell(next_head_cell):
			return true
	return false

func get_enemy_with_head_at(cell: Vector2i, exclude_enemy: Node2D = null) -> Node2D:
	for other_enemy in enemy_snakes:
		if not is_instance_valid(other_enemy) or other_enemy == exclude_enemy:
			continue
		if other_enemy.head_cell == cell:
			return other_enemy
	return null

func can_enemy_swap_heads(moving_enemy: Node2D, next_head_cell: Vector2i) -> bool:
	var blocking_enemy: Node2D = get_enemy_with_head_at(next_head_cell, moving_enemy)
	if blocking_enemy == null:
		return false

	var blocking_dir: Vector2i = blocking_enemy.get_effective_direction(grid_controller)
	if blocking_dir == Vector2i.ZERO:
		blocking_dir = blocking_enemy.direction
	if blocking_dir == Vector2i.ZERO:
		return false
	if not grid_controller.can_move(blocking_enemy.head_cell, blocking_dir):
		return false

	return blocking_enemy.head_cell + blocking_dir == moving_enemy.head_cell

func try_resolve_enemy_head_swap(moving_enemy: Node2D, next_head_cell: Vector2i, moving_dir: Vector2i) -> bool:
	var blocking_enemy: Node2D = get_enemy_with_head_at(next_head_cell, moving_enemy)
	if blocking_enemy == null:
		return false
	if not can_enemy_swap_heads(moving_enemy, next_head_cell):
		return false
	if not grid_controller.can_move(moving_enemy.head_cell, moving_dir):
		return false

	if not blocking_enemy.advance(grid_controller):
		return false
	enemy_moved_this_frame[blocking_enemy] = true

	if not moving_enemy.advance(grid_controller):
		return false
	enemy_moved_this_frame[moving_enemy] = true
	return true

func eliminate_snake(target: Node2D) -> void:
	if target == snake:
		trigger_game_over()
		return

	var idx: int = enemy_snakes.find(target)
	if idx != -1:
		enemy_snakes.remove_at(idx)
		enemy_objective_by_id.erase(get_enemy_id(target))
		enemy_objective_until_by_id.erase(get_enemy_id(target))
	if is_instance_valid(target):
		target.queue_free()

func get_player_reachable_cells() -> Dictionary:
	var reachable: Dictionary = {}
	if grid_controller == null or grid_controller.level == null:
		return reachable
	if not grid_controller.is_inside_grid(snake.head_cell):
		return reachable

	var queue: Array[Vector2i] = [snake.head_cell]
	var read_index: int = 0
	reachable[snake.head_cell] = true
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

	while read_index < queue.size():
		var current: Vector2i = queue[read_index]
		read_index += 1
		for dir in dirs:
			if not grid_controller.can_move(current, dir):
				continue
			var next_cell: Vector2i = current + dir
			if reachable.has(next_cell):
				continue
			reachable[next_cell] = true
			queue.append(next_cell)

	return reachable

func get_free_cells(reachable_cells: Dictionary = {}) -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	var level = grid_controller.level
	for y in range(level.height):
		for x in range(level.width):
			var cell := Vector2i(x, y)
			if not reachable_cells.is_empty() and not reachable_cells.has(cell):
				continue
			if snake.contains_cell(cell):
				continue

			var blocked: bool = false
			for enemy in enemy_snakes:
				if is_instance_valid(enemy) and enemy.contains_cell(cell):
					blocked = true
					break
			if blocked:
				continue

			for ext in extensions:
				if is_instance_valid(ext) and ext.cell == cell:
					blocked = true
					break
			if not blocked:
				free.append(cell)
	return free

func spawn_extension() -> void:
	if extension_scene == null:
		return
	var reachable_cells: Dictionary = get_player_reachable_cells()
	var free_cells := get_free_cells(reachable_cells)
	if free_cells.is_empty():
		return
	var cell: Vector2i = free_cells[randi() % free_cells.size()]
	var ext: Node2D = extension_scene.instantiate()
	get_parent().add_child(ext)
	ext.setup(cell, randi_range(1, 6), grid_controller.get_maze_offset(), snake.tile_size)
	extensions.append(ext)

func consume_extension_at_cell(cell: Vector2i, consumer: Node2D, is_player_consumer: bool) -> void:
	for i in range(extensions.size() - 1, -1, -1):
		var ext = extensions[i]
		if not is_instance_valid(ext):
			extensions.remove_at(i)
			continue
		if ext.cell == cell:
			if consumer != null and consumer.has_method("grow"):
				consumer.grow()
			if is_player_consumer:
				score += ext.value
				update_score_label()
			play_pickup_sfx()
			ext.queue_free()
			extensions.remove_at(i)
			spawn_extension()

func update_score_label() -> void:
	if score_label:
		score_label.text = "Score: " + str(score)

func update_level_label() -> void:
	if level_label:
		var total_levels: int = max(1, level_paths.size())
		level_label.text = "Poziom: %d/%d" % [current_level_index + 1, total_levels]

func trigger_game_over() -> void:
	game_over_ui.visible = true
	is_running = false
	state = GameState.GAME_OVER

func queue_direction(new_direction: Vector2i) -> void:
	if new_direction == Vector2i.ZERO:
		return
	queued_direction = new_direction
	reset_player_wall_block_state()

func try_apply_swipe(swipe_delta: Vector2) -> bool:
	if swipe_delta.length() < swipe_min_distance:
		return false

	var swipe_direction: Vector2i
	if absf(swipe_delta.x) >= absf(swipe_delta.y):
		swipe_direction = Vector2i.RIGHT if swipe_delta.x > 0.0 else Vector2i.LEFT
	else:
		swipe_direction = Vector2i(0, 1) if swipe_delta.y > 0.0 else Vector2i(0, -1)

	queue_direction(swipe_direction)
	return true

func _input(event: InputEvent) -> void:
	if not is_running:
		return

	if event.is_action_pressed("snake_right") or event.is_action_pressed("ui_right"):
		queue_direction(Vector2i.RIGHT)
	elif event.is_action_pressed("snake_left") or event.is_action_pressed("ui_left"):
		queue_direction(Vector2i.LEFT)
	elif event.is_action_pressed("snake_up") or event.is_action_pressed("ui_up"):
		queue_direction(Vector2i(0, -1))
	elif event.is_action_pressed("snake_down") or event.is_action_pressed("ui_down"):
		queue_direction(Vector2i(0, 1))
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			active_swipe_index = touch_event.index
			swipe_start_position = touch_event.position
		elif touch_event.index == active_swipe_index:
			try_apply_swipe(touch_event.position - swipe_start_position)
			active_swipe_index = -1
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if drag_event.index != active_swipe_index:
			return
		if try_apply_swipe(drag_event.position - swipe_start_position):
			active_swipe_index = -1
