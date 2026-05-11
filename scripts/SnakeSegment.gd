extends Node2D

@export var tile_size: float = 64.0
@onready var sprite: Sprite2D = $Sprite2D

func _get_sprite() -> Sprite2D:
	if sprite != null:
		return sprite
	return get_node_or_null("Sprite2D") as Sprite2D

func set_tile_size(value: float) -> void:
	tile_size = maxf(1.0, value)
	_apply_texture_scale()

func set_visual(texture: Texture2D, rotation_angle: float = 0.0, flip_h: bool = false, flip_v: bool = false) -> void:
	var target_sprite: Sprite2D = _get_sprite()
	if target_sprite == null:
		return
	target_sprite.texture = texture
	target_sprite.rotation = rotation_angle
	target_sprite.flip_h = flip_h
	target_sprite.flip_v = flip_v
	target_sprite.centered = true
	_apply_texture_scale()

func _apply_texture_scale() -> void:
	var target_sprite: Sprite2D = _get_sprite()
	if target_sprite == null:
		return
	if target_sprite.texture == null:
		return
	var tex_size: Vector2 = target_sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	target_sprite.scale = Vector2(tile_size / tex_size.x, tile_size / tex_size.y)

func set_head(texture: Texture2D) -> void:
	set_visual(texture, 0.0)

func set_body(texture: Texture2D) -> void:
	set_visual(texture, 0.0)

func update_visual(is_corner: bool, rotation_angle: float, texture: Texture2D) -> void:
	if is_corner:
		set_visual(texture, rotation_angle)
	else:
		set_visual(texture, 0.0)
