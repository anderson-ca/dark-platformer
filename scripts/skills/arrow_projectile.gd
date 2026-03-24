class_name ArrowProjectile
extends BaseProjectile

func _init() -> void:
	projectile_name = "Arrow"

	# Bullets 03 spritesheets — white physical
	bullet_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 03/Spritesheets/Bullet 03.png"
	muzzle_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 03/Spritesheets/Bullet Muzzle 03.png"
	hit_texture_path = "res://assets/effects/combat/projectiles/Battle VFX projectiles/Bullets 03/Spritesheets/Bullet Hit 03 1.png"

	# Arrow is very fast, piercing feel
	speed = 400.0
	damage = 1
	knockback_force = 50.0

	# Frame data — all 240x48 = 5 frames
	bullet_frame_count = 5
	bullet_frame_size = Vector2(48, 48)
	muzzle_frame_count = 5
	muzzle_frame_size = Vector2(48, 48)
	hit_frame_count = 5
	hit_frame_size = Vector2(48, 48)
