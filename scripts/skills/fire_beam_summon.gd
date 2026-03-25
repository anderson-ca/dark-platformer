class_name FireBeamSummon
extends BaseSummon

func _init():
	summon_name = "Fire Beam"
	texture_path = ""

	frame_size = Vector2(48, 48)
	animation_speed = 12.0

	damage = 4
	knockback_force = 200.0
	spawn_offset = Vector2(60, 9)

	hitbox_start_frame = 2
	hitbox_end_frame = 8

	match_environment_color = false
	magical_aura_enabled = false
	ghost_interval = 0.04


func _setup_animation():
	# Note: double space in folder name
	var base_path = "res://assets/effects/combat/summons/Fire beam  Separated Frames/"

	var sf = SpriteFrames.new()
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	for i in range(1, 11):
		var texture = load(base_path + "Fire Beam" + str(i) + ".png")
		if texture:
			sf.add_frame("summon", texture)
		else:
			push_error("Could not load: Fire Beam" + str(i) + ".png")

	animated_sprite.sprite_frames = sf
	frame_count = 10

	# Scale only the sprite, not the node (avoids scaling hitbox)
	animated_sprite.scale = Vector2(2.0, 12.0)
	animated_sprite.centered = true
	# Anchor bottom at ground: shift up by half the scaled height (48 * 12 / 2 = 288)
	animated_sprite.position.y = -288

	print("Fire Beam: ", frame_count, " frames loaded")
