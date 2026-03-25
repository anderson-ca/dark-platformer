class_name EarthTrapSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Trap"
	texture_path = ""

	frame_size = Vector2(48, 48)
	animation_speed = 10.0

	damage = 2
	knockback_force = 200.0
	spawn_offset = Vector2(80, -20)

	# Hitbox active during hold/attack phase (frames 7-10, index 6-9)
	hitbox_start_frame = 6
	hitbox_end_frame = 9


func _ready() -> void:
	super._ready()
	scale = Vector2(2.0, 2.0)


func _setup_animation() -> void:
	var base_path := "res://assets/effects/combat/summons/Earth Trap A/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	var textures: Array[Texture2D] = []

	for i in range(1, 17):
		var texture := load(base_path + "Earth trap A" + str(i) + ".png") as Texture2D
		if texture:
			textures.append(texture)
		else:
			push_error("Could not load: Earth trap A" + str(i) + ".png")

	if textures.size() == 0:
		push_error("No Earth Trap frames loaded!")
		return

	var rise_frames := 6   # Frames 1-6: rising
	var hold_frames := 4   # Frames 7-10: full wall/attack

	# Part 1: rise from ground (frames 1-6)
	for i in range(rise_frames):
		sf.add_frame("summon", textures[i])

	# Part 2: hold/attack (frames 7-10)
	for i in range(rise_frames, rise_frames + hold_frames):
		sf.add_frame("summon", textures[i])

	# Part 3: sink into ground (reversed rise, skip ugly symmetrical fade)
	for i in range(rise_frames - 1, -1, -1):
		sf.add_frame("summon", textures[i])

	animated_sprite.sprite_frames = sf
	frame_count = rise_frames + hold_frames + rise_frames  # 16

	print("Earth Trap: ", frame_count, " frames")
	print("  - 1-6: rise | 7-10: attack | 11-16: sink (reversed rise)")
