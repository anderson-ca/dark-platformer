class_name EarthHammerSummon
extends BaseSummon

func _init() -> void:
	summon_name = "Earth Hammer"
	texture_path = "res://assets/effects/combat/summons/Earth Hammer/Earth Hammer Separeted Frames/Earth Hammer (48x48).png"

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
