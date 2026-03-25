class_name EarthGolemSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Golem"
	texture_path = "res://scenes/summons/Earth Golem (56x56).png"

	# 784x336 sprite sheet: 14 cols x 6 rows of 56x56
	# Rows: 6 + 5 + 14 + 14 + 14 + 14 = ~67 frames, using all 84 cells (empty ones are transparent)
	frame_count = 67
	frame_size = Vector2(56, 56)
	cols = 14
	animation_speed = 15.0

	# Golem hits hard
	damage = 4
	knockback_force = 300.0

	# Spawn in front of player
	spawn_offset = Vector2(45, -10)

	# Hitbox active during slam/attack frames (rows 3-4, roughly frames 11-38)
	hitbox_start_frame = 11
	hitbox_end_frame = 38
