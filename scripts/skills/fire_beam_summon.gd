class_name FireBeamSummon
extends BaseSummon

func _init():
	summon_name = "Fire Beam"
	texture_path = ""
	frame_size = Vector2(32, 32)
	animation_speed = 12.0
	damage = 4
	knockback_force = 200.0
	spawn_offset = Vector2(60, 9)
	hitbox_start_frame = 2
	hitbox_end_frame = 8
	match_environment_color = false
	magical_aura_enabled = false

func _setup_animation():
	# Note: double space in folder name
	var base_path = "res://assets/effects/combat/summons/Fire beam  Separated Frames/"

	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("summon")
	sprite_frames.set_animation_speed("summon", animation_speed)
	sprite_frames.set_animation_loop("summon", false)

	for i in range(1, 11):
		var file_path = base_path + "Fire Beam" + str(i) + ".png"
		var texture = load(file_path)
		if texture:
			sprite_frames.add_frame("summon", texture)

	animated_sprite.sprite_frames = sprite_frames
	frame_count = 10

	# centered=false means sprite draws downward from top-left
	# So we position it above the origin so it extends upward
	animated_sprite.centered = false
	animated_sprite.scale = Vector2(2.0, 12.0)
	# Sprite is 32px * 12 = 384px tall. Move it up by that amount so bottom sits at y=0
	animated_sprite.position.y = -384

	# Add fire glow light
	var light = PointLight2D.new()
	light.name = "FireGlow"
	light.color = Color(1.0, 0.6, 0.2)
	light.energy = 2.5
	light.texture_scale = 3.0
	light.position = Vector2(0, -150)
	light.blend_mode = Light2D.BLEND_MODE_ADD

	# Create radial gradient texture for light
	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0
	for y in range(size):
		for x in range(size):
			var dist = Vector2(x, y).distance_to(center)
			var alpha = clampf(1.0 - dist / radius, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	light.texture = ImageTexture.create_from_image(img)

	add_child(light)

	# Pulse the light for flickering fire effect
	var tween = create_tween().set_loops()
	tween.tween_property(light, "energy", 3.0, 0.1)
	tween.tween_property(light, "energy", 2.0, 0.1)
	tween.tween_property(light, "energy", 2.8, 0.08)
	tween.tween_property(light, "energy", 2.2, 0.12)
