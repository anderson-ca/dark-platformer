class_name FireBeamSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Fire Beam"
	texture_path = ""

	frame_size = Vector2(32, 32)
	animation_speed = 12.0

	damage = 4
	knockback_force = 200.0
	spawn_offset = Vector2(60, -20)

	hitbox_start_frame = 2
	hitbox_end_frame = 8

	match_environment_color = false

	magical_aura_enabled = false
	aura_color = Color(1.0, 0.4, 0.1, 1.0)  # #FF6619
	ghost_interval = 0.04


func _ready() -> void:
	super._ready()
	scale = Vector2(2.0, 6.0)


func _setup_animation() -> void:
	# Note: double space in folder name
	var base_path := "res://assets/effects/combat/summons/Fire beam  Separated Frames/"

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	var textures: Array[Texture2D] = []

	for i in range(1, 11):
		var texture := load(base_path + "Fire Beam" + str(i) + ".png") as Texture2D
		if texture:
			textures.append(texture)
		else:
			push_error("Could not load: Fire Beam" + str(i) + ".png")

	if textures.size() == 0:
		push_error("No Fire Beam frames loaded!")
		return

	for tex in textures:
		sf.add_frame("summon", tex)

	animated_sprite.sprite_frames = sf
	frame_count = textures.size()

	print("Fire Beam: ", frame_count, " frames @ ", animation_speed, " FPS")
