class_name EarthTrapSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Trap"
	texture_path = ""  # Using individual frames

	frame_size = Vector2(64, 32)
	animation_speed = 18.0

	damage = 2
	knockback_force = 200.0
	spawn_offset = Vector2(60, 10)

	# Hitbox active when trap springs
	hitbox_start_frame = 6
	hitbox_end_frame = 12


func _setup_animation() -> void:
	var base_path := "res://assets/effects/combat/summons/Earth Trap A/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	var total_frames := 0

	for i in range(1, 17):  # 1 to 16
		var texture := load(base_path + "Earth trap A" + str(i) + ".png") as Texture2D
		if texture:
			sf.add_frame("summon", texture)
			total_frames += 1
		else:
			push_error("Could not load: Earth trap A" + str(i) + ".png")

	animated_sprite.sprite_frames = sf
	frame_count = total_frames
	print("Earth Trap: loaded ", total_frames, " frames")
