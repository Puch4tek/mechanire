extends Node2D

const POINT_TEXTURES := {
	1: preload("res://assets/points/pkt1.png"),
	2: preload("res://assets/points/pkt2.png"),
	3: preload("res://assets/points/pkt3.png"),
	4: preload("res://assets/points/pkt4.png"),
	5: preload("res://assets/points/pkt5.png"),
	6: preload("res://assets/points/pkt6.png"),
}

var value: int = 1
var cell: Vector2i

func setup(grid_cell: Vector2i, v: int, maze_offset: Vector2, tile_size: int) -> void:
	cell = grid_cell
	value = clampi(v, 1, 6)
	apply_point_visual(tile_size)
	position = maze_offset + Vector2(
		grid_cell.x * tile_size + tile_size / 2.0,
		grid_cell.y * tile_size + tile_size / 2.0
	)

func apply_point_visual(tile_size: int) -> void:
	var sprite: Sprite2D = $Sprite2D
	var label: Label = $Label
	var background: ColorRect = $Background
	var texture: Texture2D = POINT_TEXTURES.get(value)

	if texture != null:
		sprite.texture = texture
		sprite.visible = true
		label.visible = false
		background.visible = false

		var source_size: Vector2 = texture.get_size()
		if source_size.x > 0.0 and source_size.y > 0.0:
			# Dopasowanie do kafelka bez zniekształceń proporcji.
			var scale_factor: float = minf(float(tile_size) / source_size.x, float(tile_size) / source_size.y)
			sprite.scale = Vector2.ONE * scale_factor
		return

	# Fallback jeśli plik tekstury będzie brakował.
	sprite.visible = false
	label.visible = true
	background.visible = true
	label.text = str(value)

