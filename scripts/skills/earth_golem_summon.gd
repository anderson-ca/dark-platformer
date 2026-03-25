class_name EarthGolemSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Golem"
	texture_path = ""  # Not using sprite sheet

	frame_size = Vector2(56, 56)
	animation_speed = 15.0

	damage = 4
	knockback_force = 300.0
	spawn_offset = Vector2(45, -10)


func _setup_animation() -> void:
	# Load frames from multiple folders in sequence: Casting → Attack → Death
	var base_path := "res://scenes/summons/Earth Golem Separeted Frames/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	var total_frames := 0

	# 1. CASTING (appear)
	var casting_path := base_path + "Casting/"
	var casting_count := _count_frames(casting_path, "Earth GolemCasting")
	for i in range(1, casting_count + 1):
		var texture := load(casting_path + "Earth GolemCasting" + str(i) + ".png") as Texture2D
		if texture:
			sf.add_frame("summon", texture)
			total_frames += 1
	print("Loaded ", casting_count, " Casting frames")

	# Track where attack starts for hitbox timing
	var attack_start_frame := total_frames

	# 2. ATTACK 1
	var attack_path := base_path + "Attack 1/"
	var attack_count := _count_frames(attack_path, "Earth GolemAttacking")
	for i in range(1, attack_count + 1):
		var texture := load(attack_path + "Earth GolemAttacking" + str(i) + ".png") as Texture2D
		if texture:
			sf.add_frame("summon", texture)
			total_frames += 1
	print("Loaded ", attack_count, " Attack frames")

	# 3. DEATH (disappear)
	var death_path := base_path + "Death/"
	var death_count := _count_frames(death_path, "Earth GolemDeath")
	for i in range(1, death_count + 1):
		var texture := load(death_path + "Earth GolemDeath" + str(i) + ".png") as Texture2D
		if texture:
			sf.add_frame("summon", texture)
			total_frames += 1
	print("Loaded ", death_count, " Death frames")

	animated_sprite.sprite_frames = sf
	frame_count = total_frames

	# Set hitbox active during attack portion
	hitbox_start_frame = attack_start_frame + 4
	hitbox_end_frame = attack_start_frame + 8

	print("Earth Golem: ", total_frames, " total frames, hitbox active frames ", hitbox_start_frame, "-", hitbox_end_frame)


func _count_frames(folder_path: String, prefix: String) -> int:
	var count := 0
	for i in range(1, 50):
		if ResourceLoader.exists(folder_path + prefix + str(i) + ".png"):
			count += 1
		else:
			break
	return count
