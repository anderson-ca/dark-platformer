class_name EarthGolemSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Golem"
	texture_path = "res://scenes/summons/Earth Golem (56x56).png"

	# 784x336 sprite sheet: 14 cols x 6 rows of 56x56
	# Skip partial rows 1-2 (6+5=11 frames), use 3 full rows (42 frames)
	frame_count = 42
	frame_size = Vector2(56, 56)
	cols = 14
	start_frame = 11  # Skip rows 1-2
	animation_speed = 15.0

	# Golem hits hard
	damage = 4
	knockback_force = 300.0

	# Spawn in front of player
	spawn_offset = Vector2(45, -10)

	# Hitbox active during slam frames (relative to our 42-frame range)
	hitbox_start_frame = 8
	hitbox_end_frame = 20
