# UNUSED — kept for future projectile types
class_name LightningProjectile
extends BaseProjectile

func _init() -> void:
	projectile_name = "Lightning"

	# Bullets 05 spritesheets — yellow electric
	bullet_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 05/Spritesheets/Bullet 05.png"
	muzzle_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 05/Spritesheets/Bullet Muzzle 05.png"
	hit_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 05/Spritesheets/Bullet Hit 05.png"

	# Lightning is fast
	speed = 350.0
	damage = 1
	knockback_force = 80.0

	# Frame data — Bullet: 240x48 = 5 frames, Muzzle: 240x48 = 5 frames, Hit: 336x48 = 7 frames
	bullet_frame_count = 5
	bullet_frame_size = Vector2(48, 48)
	muzzle_frame_count = 5
	muzzle_frame_size = Vector2(48, 48)
	hit_frame_count = 7
	hit_frame_size = Vector2(48, 48)
