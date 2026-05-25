# Referencja kodu (API skryptów)

Ten dokument jest referencją "co gdzie jest" w warstwie GDScript.

## Konwencja

- **Public hook** - metoda używana przez sygnał, inny skrypt albo scenę.
- **Internal** - metoda pomocnicza, zwykle niepowiązana bezpośrednio z UI.

---

## `scripts/GameController.gd`

Główny orchestrator gameplayu i stanu kampanii.

### Public hooks

- `start_game()` - alias kompatybilności, uruchamia kampanię.
- `queue_direction(new_direction)` - przyjmuje kierunek od UI/input.
- `reset_current_level()` - restartuje bieżący poziom.

### Lifecycle

- `_ready()`
- `_process(delta)`
- `_input(event)`

### Kampania / poziomy

- `start_campaign()`
- `load_level_by_index(index)`
- `start_level()`
- `go_to_next_level()`
- `trigger_level_clear()`
- `_on_next_level_button_pressed()`

### Tick ruchu

- `run_player_frame(delta)`
- `ensure_player_continuous_direction(delta)`
- `choose_player_wall_turn(blocked_dir)`
- `run_enemy_frame(delta)`
- `try_advance_snake(moving_snake)`

### AI enemy

- `update_enemy_directions()`
- `choose_enemy_direction(enemy, reserved_heads, enemy_index)`
- `choose_enemy_nonblocking_direction(enemy, reserved_heads)`
- `score_enemy_direction(enemy, dir, enemy_index)`
- `get_enemy_objective(enemy, enemy_index)`
- `get_nearest_extension_cell(enemy)`
- `get_player_target_cell(enemy_index)`
- `enemy_separation_score(enemy, next_head, dir)`
- `cleanup_enemy_objective_cache()`

### Spawny enemy

- `spawn_enemy_snakes()`
- `update_enemy_release(delta)`
- `spawn_next_enemy_from_queue()`
- `is_enemy_spawn_valid(spawn_data)`
- `is_enemy_runtime_valid(enemy)`

### Kolizje / zjadanie

- `try_consume_enemy_head_from_behind(...)`
- `try_consume_player_head_from_behind(...)`
- `try_consume_shorter_head_from_front(...)`
- `_can_consume_from_front(...)`
- `find_rear_end_target_grid(...)`
- `consume_tail_target(...)`
- `check_head_collision(...)`
- `snake_would_collide(enemy, dir)`
- `try_resolve_enemy_head_swap(...)`

### Extensions / score / audio

- `spawn_extension()`
- `consume_extension_at_cell(cell, consumer, is_player_consumer)`
- `update_score_label()`
- `play_pickup_sfx()`
- `play_eat_segment_sfx()`

### Stan i pola krytyczne

- `state` (`RUNNING`, `GAME_OVER`, `LEVEL_CLEAR`)
- `enemy_snakes`, `extensions`
- `current_level_index`, `level_paths`
- commit celu AI:
  - `enemy_objective_commit_time`
  - `enemy_objective_by_id`
  - `enemy_objective_until_by_id`
- auto-skręt gracza:
  - `player_auto_turn_delay`
  - `player_wall_block_time`
  - `player_wall_block_dir`
  - `player_wall_block_cell`

### Ultra-API (`GameController`) - tabela

| Funkcja | Parametry | Zwraca | Side effects |
|---|---|---|---|
| `start_campaign()` | brak | `void` | resetuje `score`, `current_level_index`, ładuje level 1 |
| `load_level_by_index(index)` | `index: int` | `bool` | ustawia `current_level_index`, buduje planszę, wywołuje `start_level()` |
| `start_level()` | brak | `void` | czyści enemy/extensions, resetuje cache AI, spawnuje gracza/enemy/pickup, resetuje UI |
| `run_player_frame(delta)` | `delta: float` | `void` | utrzymuje ciągły ruch gracza, zużywa step budget, wykonuje ruchy, konsumuje extensiony |
| `ensure_player_continuous_direction(delta)` | `delta: float` | `void` | przy blokadzie na wprost po krótkim opóźnieniu wymusza auto-skręt, aktualizuje `queued_direction` |
| `choose_player_wall_turn(blocked_dir)` | `blocked_dir: Vector2i` | `Vector2i` | wybiera losowo legalny kierunek z kandydatów lewo/prawo |
| `run_enemy_frame(delta)` | `delta: float` | `void` | zużywa step budget enemy, wykonuje ruchy AI, konsumuje extensiony |
| `update_enemy_directions()` | brak | `void` | aktualizuje kierunki enemy z rezerwacją pól i cleanup cache |
| `choose_enemy_direction(enemy, reserved_heads, enemy_index)` | `Node2D`, `Dictionary`, `int` | `Vector2i` | brak bezpośrednich, wylicza kierunek najlepszego ruchu |
| `choose_enemy_nonblocking_direction(enemy, reserved_heads)` | `Node2D`, `Dictionary` | `Vector2i` | fallback: wybiera legalny ruch, który nie wchodzi w pola innych enemy |
| `score_enemy_direction(enemy, dir, enemy_index)` | `Node2D`, `Vector2i`, `int` | `float` | brak; liczy wynik heurystyki |
| `get_enemy_objective(enemy, enemy_index)` | `Node2D`, `int` | `Dictionary` | zapisuje/odświeża commit celu w cache |
| `try_advance_snake(moving_snake)` | `Node2D` | `bool` | może eliminować węże, zmieniać `score`, wywoływać grow/shrink |
| `consume_extension_at_cell(cell, consumer, is_player_consumer)` | `Vector2i`, `Node2D`, `bool` | `void` | usuwa extension, grow konsumenta, update score (gracz), spawn nowego extensiona |
| `trigger_game_over()` | brak | `void` | ustawia `state=GAME_OVER`, `is_running=false`, pokazuje `GameOver` |
| `trigger_level_clear()` | brak | `void` | ustawia `state=LEVEL_CLEAR`, `is_running=false`, pokazuje `LevelComplete` |
| `go_to_next_level()` | brak | `void` | ładuje kolejny poziom albo restartuje kampanię |
| `reset_current_level()` | brak | `void` | restartuje bieżący poziom przez `load_level_by_index(current_level_index)` |

---

## `scripts/Snake.gd`

Model pojedynczego węża (gracz lub enemy).

### Public hooks

- `spawn_snake(start, length, initial_direction)`
- `grow()`
- `shrink_tail(count, min_length)`
- `set_direction(new_dir)`
- `contains_cell(cell)`
- `advance(grid_controller, ignore_walls=false)`
- `consume_step_budget(delta)`
- `get_effective_direction(grid_controller, ignore_walls=false)`

### Internal

- `grid_to_world(cell)`
- `can_apply_requested_direction(...)`
- `update_positions()`
- helpery rotacji/transformacji:
  - `_dir_to_rotation(...)`
  - `_corner_rotation(...)`
  - `_transition_corner_transform(...)`
  - `_head_transition_corner_transform(...)`

### Dane krytyczne

- `segment_cells`, `previous_segment_cells`
- `head_cell`, `direction`, `requested_direction`
- `tile_size`, `move_speed_px`, `maze_offset`

### Ultra-API (`Snake`) - tabela

| Funkcja | Parametry | Zwraca | Side effects |
|---|---|---|---|
| `spawn_snake(start, length, initial_direction)` | `Vector2i`, `int`, `Vector2i` | `void` | czyści poprzednie segmenty, tworzy nowe node'y segmentów, resetuje kierunek i akumulator |
| `grow()` | brak | `void` | dodaje segment ogona, odświeża pozycje/render |
| `shrink_tail(count, min_length)` | `int`, `int` | `int` (ile usunięto) | usuwa segmenty ogona, queue_free, odświeża render |
| `set_direction(new_dir)` | `Vector2i` | `void` | aktualizuje `requested_direction` |
| `contains_cell(cell)` | `Vector2i` | `bool` | brak |
| `consume_step_budget(delta)` | `float` | `int` | zwiększa/zmniejsza `move_accumulator` |
| `advance(grid_controller, ignore_walls=false)` | `Node`, `bool` | `bool` | przesuwa `segment_cells`, aktualizuje `head_cell`, renderuje pozycje |
| `get_effective_direction(grid_controller, ignore_walls=false)` | `Node`, `bool` | `Vector2i` | brak |
| `can_move_forward(grid_controller, for_dir, ignore_walls=false)` | `Node`, `Vector2i`, `bool` | `bool` | brak |
| `update_positions()` | brak | `void` | ustawia world pozycje segmentów, z-index i przypisuje tekstury/rotacje |

---

## `scripts/GridController.gd`

Obsługa siatki ścian i tilemapy.

### Public hooks

- `load_and_build(path)`
- `can_move(cell, dir)`
- `is_inside_grid(cell)`
- `get_maze_offset()`
- `get_snake_spawn()`

### Internal

- `load_level(path)`
- `build_grid()`
- `render_tilemap()`
- `center_maze()`

### Dane

- `level: LevelData`
- `grid` (macierz komórek ścian)

---

## `scripts/Game.gd`

Warstwa UI/HUD i delegacja inputu do `GameController`.

### Public hooks (sygnały sceny)

- `_on_reset_button_pressed()`
- `_on_pause_button_pressed()`
- `_on_arrow_up_pressed()`
- `_on_arrow_left_pressed()`
- `_on_arrow_right_pressed()`
- `_on_arrow_down_pressed()`

### Layout

- `_layout_hud()`
- `_get_board_rect()`
- `_get_safe_rect()`
- `_clamp_rect_top_left(...)`
- `_set_control_rect(...)`
- `_layout_dpad_buttons(scale_factor)`

### Delegacja inputu

- `_queue_arrow_direction(dir)` -> `GameController.queue_direction(...)`

---

## `scripts/LevelData.gd`

Resource danych poziomu.

### Public API

- `get_cell_mask(x, y)` - zwraca maskę ścian dla komórki.

### Dane

- `width`, `height`
- `snake_spawn`
- parametry boksów gracza/enemy
- `cells_2d` (preferowane)
- `cells` (legacy fallback)

---

## `scripts/Extension.gd`

Model pickupa extension.

### Public API

- `setup(grid_cell, v, maze_offset, tile_size)`
- `apply_point_visual(tile_size)`

### Dane

- `value`
- `cell`
- `POINT_TEXTURES` (mapowanie `1..6` -> `assets/points/pktX.png`)

---

## `scripts/SnakeSegment.gd`

Pojedynczy segment wizualny węża.

### Public API

- `set_tile_size(value)`
- `set_visual(texture, rotation_angle, flip_h, flip_v)`
- `set_head(texture)`
- `set_body(texture)`
- `update_visual(is_corner, rotation_angle, texture)`

### Internal

- `_get_sprite()`
- `_apply_texture_scale()`

---

## `scripts/StartScreen.gd`

Kontroler ekranu startowego.

### Public hooks

- `_on_button_pressed()`
- `start_game()`

### Internal

- `setup_background_fill()`
- `configure_background_display()`
- `update_background_layout()`
- `_input(event)`

---

## `scripts/pause.gd`

### Public hooks

- `_on_button_pressed()` - zamyka pauzę i wznawia `get_tree().paused = false`.

---

## `scripts/GameOver.gd`

### Public hooks

- `_on_button_pressed()` - przejście do `Game.tscn` przez autoload `Transition`.

---

## `scripts/SceneTransition.gd`

Autoload do fade in/out między scenami.

### Public API

- `fade_to_scene(path)`

---

## `scripts/BoardAreaHelper.gd` (`@tool`)

Narzędzie edytorowe do podglądu obszaru planszy.

### Public / editor hooks

- `_ready()`
- `_process(_delta)`
- `_draw()`

### Internal

- `_get_board_rect()`

---

## `scripts/TileMapDrawTest.gd`

Skrypt testowy/debug dla rysowania tilemapy myszą.

### API

- `_input(event)` - przy `mb_left` stawia komórkę w tilemapie.

---

## Szybkie punkty wejścia do debugowania

- "Dlaczego nie działa ruch?" -> `GridController.can_move`, `Snake.advance`, `GameController.try_advance_snake`.
- "Dlaczego AI jedzie dziwnie?" -> `update_enemy_directions`, `score_enemy_direction`, `get_enemy_objective`.
- "Dlaczego HUD jest źle ustawiony?" -> `Game._layout_hud`, `_get_safe_rect`.
- "Dlaczego level się nie ładuje?" -> `LevelData.get_cell_mask`, `GridController.load_and_build`.


