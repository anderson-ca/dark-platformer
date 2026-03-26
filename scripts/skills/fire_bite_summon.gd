class_name FireBiteSummon
extends BaseSummon

var _light: PointLight2D = null


func _init():
	summon_name = "Fire Bite"
	texture_path = ""
	frame_size = Vector2(64, 64)
	animation_speed = 14.0
	damage = 2
	knockback_force = 150.0
	spawn_offset = Vector2(70, -15)
	hitbox_start_frame = 4
	hitbox_end_frame = 16
	match_environment_color = false
	magical_aura_enabled = true
	aura_color = Color(1.0, 0.4, 0.1, 1.0)
	ghost_interval = 0.04


func _ready():
	super._ready()
	scale = Vector2(2.0, 2.0)
	_create_fire_glow()


func _create_fire_glow():
	_light = PointLight2D.new()
	_light.name = "FireGlow"
	_light.color = Color(1.0, 0.6, 0.2)
	_light.energy = 4.0
	_light.texture_scale = 4.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD

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
	_light.texture = ImageTexture.create_from_image(img)

	add_child(_light)

	# Flicker
	var tween = create_tween().set_loops()
	tween.tween_property(_light, "energy", 5.0, 0.1)
	tween.tween_property(_light, "energy", 3.5, 0.1)


func _setup_animation():
	# Note: double space in folder name
	var base_path = "res://assets/effects/combat/summons/Fire Bite/Fire Bite  Separated Frames/"

	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("summon")
	sprite_frames.set_animation_speed("summon", animation_speed)
	sprite_frames.set_animation_loop("summon", false)

	var loaded = 0
	for i in range(1, 23):
		var tex = load(base_path + "Fire bite" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("summon", tex)
			loaded += 1
		else:
			push_error("Could not load: Fire bite" + str(i) + ".png")

	animated_sprite.sprite_frames = sprite_frames
	frame_count = loaded

	print("Fire Bite: ", loaded, " frames loaded")


func _on_hitbox_area_entered(area: Area2D):
	var enemy = area.get_parent()
	if enemy and enemy.has_method("take_damage") and enemy not in hit_enemies:
		hit_enemies.append(enemy)

		var knockback_dir = Vector2(direction, -0.5).normalized()

		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(damage, knockback_dir * knockback_force)
		else:
			enemy.take_damage(global_position)

		if enemy.has_method("apply_burn"):
			enemy.apply_burn(3.0, 1)
			print("Fire Bite hit enemy — burn applied for 3s")

		print("Fire Bite hit enemy: ", enemy.name)
