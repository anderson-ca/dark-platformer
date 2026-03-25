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
