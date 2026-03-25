class_name EarthImpaleSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Impale"
	texture_path = ""

	frame_size = Vector2(64, 64)
	animation_speed = 8.0

	damage = 3
	knockback_force = 280.0
	spawn_offset = Vector2(70, 8)

	hitbox_start_frame = 4
	hitbox_end_frame = 9

	match_environment_color = true
	environment_base_color = Color(0.196, 0.184, 0.157)

	magical_aura_enabled = true
	aura_color = Color(1.0, 0.184, 0.227, 1.0)  # #FF2F3A
	ghost_interval = 0.05


func _ready() -> void:
	super._ready()
	scale = Vector2(2.0, 2.0)

	# Anchor to bottom so spikes rise UP from ground
	animated_sprite.centered = false
	animated_sprite.offset = Vector2(-32, -64)  # Half width left, full height up (64x64)


func _setup_animation() -> void:
	var base_path := "res://assets/effects/combat/summons/Earth Impale Separeted Frames/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	var textures: Array[Texture2D] = []

	for i in range(1, 18):
		var texture := load(base_path + "Earth Impale" + str(i) + ".png") as Texture2D
		if texture:
			textures.append(texture)
		else:
			push_error("Could not load: Earth Impale" + str(i) + ".png")

	if textures.size() == 0:
		push_error("No Earth Impale frames loaded!")
		return

	print("Earth Impale: loaded ", textures.size(), " raw frames")

	var rise_attack_end := 10  # Frames 1-10: rise + attack
	var reverse_start := 5     # Reverse frames 5-1 for sink

	# Rise and attack
	for i in range(rise_attack_end):
		sf.add_frame("summon", textures[i])

	# Sink back down (reversed)
	for i in range(reverse_start - 1, -1, -1):
		sf.add_frame("summon", textures[i])

	animated_sprite.sprite_frames = sf
	frame_count = rise_attack_end + reverse_start  # 15

	print("Earth Impale: ", frame_count, " final frames")
	print("  - 1-10: rise+attack | 11-15: sink (reversed 5-1)")
