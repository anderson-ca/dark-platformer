class_name EarthTrapSummon
extends BaseSummon

var exit_start_frame: int = 0
var rise_frame_count: int = 6

func _init() -> void:
	summon_name = "Earth Trap"
	texture_path = ""

	frame_size = Vector2(48, 48)
	animation_speed = 10.0

	damage = 2
	knockback_force = 200.0
	spawn_offset = Vector2(80, -20)

	hitbox_start_frame = 8
	hitbox_end_frame = 16


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

	# Part 1: all 16 frames (rise + attack + partial exit)
	for tex in textures:
		sf.add_frame("summon", tex)

	# Part 2: reversed rise frames for sink-into-ground exit
	for i in range(rise_frame_count - 1, -1, -1):
		sf.add_frame("summon", textures[i])

	animated_sprite.sprite_frames = sf
	frame_count = textures.size() + rise_frame_count  # 22
	exit_start_frame = textures.size()  # 16

	print("Earth Trap: ", frame_count, " frames total")
	print("  - Frames 1-16: original animation")
	print("  - Frames 17-22: reversed rise (sink into ground)")
