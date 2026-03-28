class_name EarthImpaleSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Impale"
	texture_path = ""

	frame_size = Vector2(64, 64)
	animation_speed = 10.0

	damage = 3
	knockback_force = 280.0
	spawn_offset = Vector2(70, -28)

	hitbox_start_frame = 4
	hitbox_end_frame = 12

	match_environment_color = true
	environment_base_color = Color(0.196, 0.184, 0.157)

	magical_aura_enabled = true
	aura_color = Color(1.0, 0.184, 0.227, 0.4)  # #FF2F3A, subtle
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

	for i in range(1, 18):
		var texture := load(base_path + "Earth Impale" + str(i) + ".png") as Texture2D
		if texture:
			textures.append(texture)
		else:
			push_error("Could not load: Earth Impale" + str(i) + ".png")

	if textures.size() == 0:
		push_error("No Earth Impale frames loaded!")
		return

	# Use all 17 frames as-is
	for tex in textures:
		sf.add_frame("summon", tex)

	animated_sprite.sprite_frames = sf
	frame_count = textures.size()

	print("Earth Impale: using all ", frame_count, " original frames")
