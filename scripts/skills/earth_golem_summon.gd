class_name EarthGolemSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Golem"
	texture_path = ""  # Not using sprite sheet

	frame_count = 11
	frame_size = Vector2(56, 56)
	animation_speed = 15.0

	damage = 4
	knockback_force = 300.0
	spawn_offset = Vector2(45, -10)

	hitbox_start_frame = 4
	hitbox_end_frame = 8


func _setup_animation() -> void:
	# Override: load individual frame files instead of sprite sheet
	var base_path := "res://scenes/summons/Earth Golem Separeted Frames/Attack 1/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	for i in range(1, 12):  # 1 to 11
		var file_path := base_path + "Earth GolemAttacking" + str(i) + ".png"
		var texture := load(file_path) as Texture2D
		if texture:
			sf.add_frame("summon", texture)
			print("Loaded frame: ", file_path)
		else:
			push_error("Could not load frame: " + file_path)

	animated_sprite.sprite_frames = sf
	print("Earth Golem: loaded ", sf.get_frame_count("summon"), " individual frames")
