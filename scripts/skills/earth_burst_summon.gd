class_name EarthBurstSummon
extends BaseSummon

func _init():
	summon_name = "Earth Burst"
	texture_path = ""
	frame_size = Vector2(64, 48)
	animation_speed = 14.0
	damage = 3
	knockback_force = 300.0
	spawn_offset = Vector2(70, -15)

	# Hitbox only during Blast frames (after 7 Start frames)
	hitbox_start_frame = 7
	hitbox_end_frame = 16

	match_environment_color = true
	environment_base_color = Color(0.196, 0.184, 0.157)

	magical_aura_enabled = true
	aura_color = Color(1.0, 0.184, 0.227, 0.4)  # subtle
	ghost_interval = 0.05


func _ready():
	super._ready()
	scale = Vector2(2.0, 2.0)


func _setup_animation():
	var base_path = "res://assets/effects/combat/summons/Earth Burst/Earth Burst Separeted Frames/"

	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("summon")
	sprite_frames.set_animation_speed("summon", animation_speed)
	sprite_frames.set_animation_loop("summon", false)

	# Phase 1: Start frames (ground rumble / buildup)
	var start_count = 0
	for i in range(1, 8):
		var tex = load(base_path + "Earth BurstStart" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("summon", tex)
			start_count += 1
		else:
			push_error("Could not load: Earth BurstStart" + str(i) + ".png")

	# Phase 2: Blast frames (explosion)
	var blast_count = 0
	for i in range(1, 11):
		var tex = load(base_path + "Earth BurstBlast" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("summon", tex)
			blast_count += 1
		else:
			push_error("Could not load: Earth BurstBlast" + str(i) + ".png")

	# Skip Idle frames — this is a burst, not persistent

	animated_sprite.sprite_frames = sprite_frames
	frame_count = start_count + blast_count

	print("Earth Burst: Start=", start_count, " Blast=", blast_count, " Total=", frame_count)
