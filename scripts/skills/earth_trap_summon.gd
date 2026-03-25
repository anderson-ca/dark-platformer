class_name EarthTrapSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Trap"
	texture_path = ""

	frame_size = Vector2(48, 48)
	animation_speed = 6.0  # Slower for dramatic effect

	damage = 2
	knockback_force = 200.0
	spawn_offset = Vector2(80, -20)

	hitbox_start_frame = 6
	hitbox_end_frame = 9


func _ready() -> void:
	super._ready()
	scale = Vector2(2.0, 2.0)
	_apply_environment_tint()


func _apply_environment_tint() -> void:
	# Try to sample tileset texture for color matching
	var tileset_tex := load("res://assets/tilesets/mountain_pass/tileset 64x64.png") as Texture2D
	if tileset_tex:
		var img := tileset_tex.get_image()
		if img:
			var avg := _sample_average_color(img)
			# Blend: 60% ground color, 40% original earth brown
			var tint := avg.lerp(Color(0.6, 0.45, 0.35), 0.4)
			tint.a = 1.0
			animated_sprite.modulate = tint
			print("Earth Trap tint (sampled): ", tint)
			return

	# Fallback: cool dark gray-brown for mountain pass mood
	animated_sprite.modulate = Color(0.55, 0.50, 0.50, 1.0)
	print("Earth Trap tint (fallback): 0.55, 0.50, 0.50")


func _sample_average_color(img: Image) -> Color:
	var total_r := 0.0
	var total_g := 0.0
	var total_b := 0.0
	var count := 0

	var w := img.get_width()
	var h := img.get_height()
	var step_x := maxi(1, w / 8)
	var step_y := maxi(1, h / 8)

	for y in range(0, h, step_y):
		for x in range(0, w, step_x):
			var pixel := img.get_pixel(x, y)
			if pixel.a > 0.5:
				total_r += pixel.r
				total_g += pixel.g
				total_b += pixel.b
				count += 1

	if count == 0:
		return Color(0.5, 0.45, 0.4)

	return Color(total_r / count, total_g / count, total_b / count)


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

	var rise_frames := 6
	var hold_frames := 4

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
	frame_count = rise_frames + hold_frames + rise_frames  # 16

	print("Earth Trap: ", frame_count, " frames @ ", animation_speed, " FPS")
