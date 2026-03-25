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

	match_environment_color = true
	environment_base_color = Color(0.196, 0.184, 0.157)

	magical_aura_enabled = true
	aura_color = Color(0.7, 0.2, 1.0, 1.0)
	ghost_interval = 0.05


func _setup_animation() -> void:
	var base_path := "res://assets/effects/combat/summons/earth_golem/frames/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	var total_frames := 0

	# 1. CASTING (appear) — 12 frames
	var casting_path := base_path + "casting/"
	for i in range(1, 13):
		var texture := load(casting_path + "casting_%02d.png" % i) as Texture2D
		if texture:
			sf.add_frame("summon", texture)
			total_frames += 1

	# Track where attack starts for hitbox timing
	var attack_start_frame := total_frames

	# 2. ATTACK — 11 frames
	var attack_path := base_path + "attack/"
	for i in range(1, 12):
		var texture := load(attack_path + "attack_%02d.png" % i) as Texture2D
		if texture:
			sf.add_frame("summon", texture)
			total_frames += 1

	# 3. DEATH (disappear) — 14 frames
	var death_path := base_path + "death/"
	for i in range(1, 15):
		var texture := load(death_path + "death_%02d.png" % i) as Texture2D
		if texture:
			sf.add_frame("summon", texture)
			total_frames += 1

	animated_sprite.sprite_frames = sf
	frame_count = total_frames

	# Set hitbox active during attack portion
	hitbox_start_frame = attack_start_frame + 4
	hitbox_end_frame = attack_start_frame + 8

	print("=== EARTH GOLEM SUMMARY ===")
	print("Total frames: ", total_frames)
	print("Hitbox active frames: ", hitbox_start_frame, "-", hitbox_end_frame)
