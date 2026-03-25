class_name EarthTrapSummon
extends BaseSummon

const RISE_FRAMES := 6  # First 6 frames show it rising — reversed for exit

func _init() -> void:
	summon_name = "Earth Trap"
	texture_path = ""  # Using individual frames

	frame_size = Vector2(64, 32)
	animation_speed = 18.0

	damage = 2
	knockback_force = 200.0
	spawn_offset = Vector2(60, 0)

	hitbox_start_frame = 6
	hitbox_end_frame = 12


func _ready() -> void:
	super._ready()
	scale = Vector2(2.5, 2.5)


func _setup_animation() -> void:
	var base_path := "res://assets/effects/combat/summons/Earth Trap A/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	var textures: Array[Texture2D] = []

	# Load all 16 frames
	for i in range(1, 17):
		var texture := load(base_path + "Earth trap A" + str(i) + ".png") as Texture2D
		if texture:
			textures.append(texture)
		else:
			push_error("Could not load: Earth trap A" + str(i) + ".png")

	# Add frames 1-16 (rise + attack)
	for tex in textures:
		sf.add_frame("summon", tex)

	# Add reversed rise frames for sink exit (6, 5, 4, 3, 2, 1)
	for i in range(RISE_FRAMES - 1, -1, -1):
		sf.add_frame("summon", textures[i])

	animated_sprite.sprite_frames = sf
	frame_count = textures.size() + RISE_FRAMES  # 16 + 6 = 22
	print("Earth Trap: ", frame_count, " frames (including reversed exit)")
