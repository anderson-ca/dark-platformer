class_name EarthImpaleSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Impale"
	texture_path = ""

	frame_size = Vector2(64, 64)
	animation_speed = 8.0

	damage = 3
	knockback_force = 280.0
	spawn_offset = Vector2(70, -15)

	hitbox_start_frame = 5
	hitbox_end_frame = 10

	match_environment_color = true
	environment_base_color = Color(0.196, 0.184, 0.157)

	magical_aura_enabled = true
	aura_color = Color(1.0, 0.184, 0.227, 1.0)  # #FF2F3A
	ghost_interval = 0.05


func _ready() -> void:
	super._ready()
	scale = Vector2(2.0, 2.0)


func _setup_animation() -> void:
	var base_path := "res://assets/effects/combat/summons/Earth Impale Separeted Frames/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	var textures: Array[Texture2D] = []

	for i in range(1, 18):  # 1 to 17
		var texture := load(base_path + "Earth Impale" + str(i) + ".png") as Texture2D
		if texture:
			textures.append(texture)
		else:
			push_error("Could not load: Earth Impale" + str(i) + ".png")

	if textures.size() == 0:
		push_error("No Earth Impale frames loaded!")
		return

	var rise_frames := 6
	var hold_frames := 5

	# Rise from ground
	for i in range(rise_frames):
		sf.add_frame("summon", textures[i])

	# Hold/attack
	for i in range(rise_frames, rise_frames + hold_frames):
		sf.add_frame("summon", textures[i])

	# Sink into ground (reversed rise)
	for i in range(rise_frames - 1, -1, -1):
		sf.add_frame("summon", textures[i])

	animated_sprite.sprite_frames = sf
	frame_count = rise_frames + hold_frames + rise_frames  # 17

	print("Earth Impale: ", frame_count, " frames")
	print("  - 1-6: rise | 7-11: attack | 12-17: sink (reversed rise)")
