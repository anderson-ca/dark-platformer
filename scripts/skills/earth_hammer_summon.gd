class_name EarthHammerSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Hammer"
	texture_path = "res://assets/effects/combat/summons/earth_hammer/spritesheet/earth_hammer_48x48.png"

	# 240x240 sprite sheet: 5 cols x 5 rows of 48x48, 21 frames used
	frame_count = 21
	frame_size = Vector2(48, 48)
	cols = 5
	animation_speed = 18.0

	# Heavy slam damage
	damage = 3
	knockback_force = 250.0

	# Spawn in front of player
	spawn_offset = Vector2(40, -10)

	# Hitbox only active during slam
	hitbox_start_frame = 8
	hitbox_end_frame = 12

	match_environment_color = true
	environment_base_color = Color(0.196, 0.184, 0.157)
