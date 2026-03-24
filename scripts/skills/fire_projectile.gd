class_name FireProjectile
extends BaseProjectile

func _init() -> void:
	projectile_name = "Fire"

	# Bullets 01 spritesheets — 48px tall horizontal strips
	bullet_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 01/Spritesheets/Bullet 01.png"
	muzzle_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 01/Spritesheets/Bullet Muzzle 01.png"
	hit_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 01/Spritesheets/Bullet Hit 01.png"

	# Stats
	speed = 250.0
	damage = 2
	knockback_force = 120.0

	# Frame data — Bullet: 1152x48 = 24 frames, Muzzle/Hit: 288x48 = 6 frames
	bullet_frame_count = 24
	bullet_frame_size = Vector2(48, 48)
	muzzle_frame_count = 6
	muzzle_frame_size = Vector2(48, 48)
	hit_frame_count = 6
	hit_frame_size = Vector2(48, 48)
