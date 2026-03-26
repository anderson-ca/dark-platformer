class_name PetrifySummon
extends BaseSummon

func _init():
	summon_name = "Petrify"
	texture_path = ""
	frame_size = Vector2(64, 64)
	animation_speed = 12.0
	damage = 1
	knockback_force = 50.0
	spawn_offset = Vector2(70, -15)
	hitbox_start_frame = 4
	hitbox_end_frame = 10
	match_environment_color = false
	magical_aura_enabled = true
	aura_color = Color(0.5, 0.7, 0.3, 1.0)
	ghost_interval = 0.05


func _setup_animation():
	var base_path = "res://assets/effects/combat/summons/Petrify/Petrify Separeted Frames/"

	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("summon")
	sprite_frames.set_animation_speed("summon", animation_speed)
	sprite_frames.set_animation_loop("summon", false)

	var loaded = 0
	for i in range(2, 16):
		var file_path = base_path + "Medusa Scream" + str(i) + ".png"
		var texture = load(file_path)
		if texture:
			sprite_frames.add_frame("summon", texture)
			loaded += 1
		else:
			push_error("Could not load: " + file_path)

	animated_sprite.sprite_frames = sprite_frames
	frame_count = loaded

	scale = Vector2(2.0, 2.0)

	print("Petrify: ", loaded, " Medusa Scream frames loaded")


func _on_hitbox_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if enemy and enemy.has_method("take_damage") and enemy not in hit_enemies:
		hit_enemies.append(enemy)

		var knockback_dir = Vector2(direction, -0.5).normalized()

		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(damage, knockback_dir * knockback_force)
		else:
			enemy.take_damage(global_position)

		if enemy.has_method("apply_petrify"):
			enemy.apply_petrify(3.5)
			print("Petrify: applied 3.5s petrify to ", enemy.name)

		print("Petrify hit enemy: ", enemy.name)
