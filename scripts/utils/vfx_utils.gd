class_name VFXUtils


static func create_light_texture(size: int = 256) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - dist / radius, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


static func spawn_sprite_effect(parent: Node, texture_path: String, frame_count: int, frame_w: int, frame_h: int, pos: Vector2, anim_name: String = "effect", fps: float = 14.0, scale_val: Vector2 = Vector2(0.3, 0.3), modulate_color: Color = Color.WHITE) -> void:
	var tex := load(texture_path) as Texture2D
	if tex == null:
		return
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, false)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		sf.add_frame(anim_name, atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.z_index = 10
	sprite.scale = scale_val
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = pos
	sprite.modulate = modulate_color
	sprite.animation_finished.connect(sprite.queue_free)
	parent.add_child(sprite)
	sprite.play(anim_name)
