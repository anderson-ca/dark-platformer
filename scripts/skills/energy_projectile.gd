class_name EnergyProjectile
extends BaseProjectile

func _init() -> void:
	projectile_name = "Energy"

	# Bullets 04 spritesheets — orange orb
	bullet_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 04/Spritesheets/Bullet 04.png"
	muzzle_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 04/Spritesheets/Bullet Muzzle 04.png"
	hit_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 04/Spritesheets/Bullet Hit 04 1.png"

	# Energy orb — balanced
	speed = 220.0
	damage = 2
	knockback_force = 140.0

	# Frame data — Bullet: 288x48 = 6 frames, Muzzle: 288x48 = 6 frames, Hit: 336x48 = 7 frames
	bullet_frame_count = 6
	bullet_frame_size = Vector2(48, 48)
	muzzle_frame_count = 6
	muzzle_frame_size = Vector2(48, 48)
	hit_frame_count = 7
	hit_frame_size = Vector2(48, 48)
