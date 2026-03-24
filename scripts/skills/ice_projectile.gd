class_name IceProjectile
extends BaseProjectile

func _init() -> void:
	projectile_name = "Ice"

	# Bullets 10 spritesheets — cyan/ice
	bullet_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 10/Spritesheets/Bullet 10.png"
	muzzle_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 10/Spritesheets/Bullet Muzzle 10.png"
	hit_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 10/Spritesheets/Bullet Hit 10.png"

	# Ice is slower but hits harder
	speed = 180.0
	damage = 2
	knockback_force = 180.0

	# Frame data — Bullet: 288x48 = 6 frames, Muzzle: 384x48 = 8 frames, Hit: 384x48 = 8 frames
	bullet_frame_count = 6
	bullet_frame_size = Vector2(48, 48)
	muzzle_frame_count = 8
	muzzle_frame_size = Vector2(48, 48)
	hit_frame_count = 8
	hit_frame_size = Vector2(48, 48)
