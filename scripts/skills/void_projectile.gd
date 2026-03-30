# UNUSED — kept for future projectile types
class_name VoidProjectile
extends BaseProjectile

func _init() -> void:
	projectile_name = "Void"

	# Bullets 15 spritesheets — purple/cosmic, matches dark sage theme
	bullet_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 15/Spritesheets/Bullet 15.png"
	muzzle_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 15/Spritesheets/Bullet Muzzle 15.png"
	hit_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 15/Spritesheets/Bullet Hit 15.png"

	# Void is fast, lower damage but will later have special effects
	speed = 280.0
	damage = 1
	knockback_force = 100.0

	# Frame data — Bullet: 336x48 = 7 frames, Muzzle: 288x48 = 6 frames, Hit: 432x48 = 9 frames
	bullet_frame_count = 7
	bullet_frame_size = Vector2(48, 48)
	muzzle_frame_count = 6
	muzzle_frame_size = Vector2(48, 48)
	hit_frame_count = 9
	hit_frame_size = Vector2(48, 48)
