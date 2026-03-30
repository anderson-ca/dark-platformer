class_name BaseProjectile
extends Area2D

# Override these in child classes
var projectile_name: String = "Base"
var bullet_texture_path: String = ""
var muzzle_texture_path: String = ""
var hit_texture_path: String = ""

# Projectile stats (override in children)
var speed: float = 200.0
var damage: int = 1
var knockback_force: float = 150.0
var lifetime: float = 2.0

# Frame data (override based on sprite sheet)
var bullet_frame_count: int = 4
var bullet_frame_size: Vector2 = Vector2(32, 32)
var muzzle_frame_count: int = 4
var muzzle_frame_size: Vector2 = Vector2(32, 32)
var hit_frame_count: int = 4
var hit_frame_size: Vector2 = Vector2(32, 32)

# Runtime
var direction: int = 1
var hit_enemies: Array = []
var muzzle_spawn_position: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_setup_bullet_animation()
	_spawn_muzzle_effect()

	animated_sprite.flip_h = (direction == -1)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.scale = Vector2(0.7, 0.7) * animated_sprite.scale
	animated_sprite.modulate = Color(1.0, 0.4, 0.3)
	animated_sprite.play("bullet")

	collision_shape.scale = Vector2(0.7, 0.7)

	# Projectile glow light
	var light_tex := VFXUtils.create_light_texture(64)

	var light := PointLight2D.new()
	light.name = "ProjectileLight"
	light.color = Color(1.0, 0.2, 0.15)
	light.energy = 3.0
	light.texture = light_tex
	light.texture_scale = 1.3
	light.shadow_enabled = false
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)

	area_entered.connect(_on_area_entered)

	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta


func _setup_bullet_animation() -> void:
	if bullet_texture_path.is_empty():
		return

	var texture := load(bullet_texture_path) as Texture2D
	if texture == null:
		push_error("Could not load bullet texture: " + bullet_texture_path)
		return

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("bullet")
	sf.set_animation_speed("bullet", 12)
	sf.set_animation_loop("bullet", true)

	for i in range(bullet_frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * bullet_frame_size.x, 0, bullet_frame_size.x, bullet_frame_size.y)
		sf.add_frame("bullet", atlas)

	animated_sprite.sprite_frames = sf


func _spawn_muzzle_effect() -> void:
	if muzzle_texture_path.is_empty():
		return

	var texture := load(muzzle_texture_path) as Texture2D
	if texture == null:
		return

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("muzzle")
	sf.set_animation_speed("muzzle", 15)
	sf.set_animation_loop("muzzle", false)

	for i in range(muzzle_frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * muzzle_frame_size.x, 0, muzzle_frame_size.x, muzzle_frame_size.y)
		sf.add_frame("muzzle", atlas)

	var muzzle := AnimatedSprite2D.new()
	muzzle.sprite_frames = sf
	muzzle.flip_h = (direction == -1)
	muzzle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	muzzle.modulate = Color(1.0, 0.4, 0.3)

	# Spawn at hand position if set, otherwise at projectile position
	get_parent().add_child(muzzle)
	if muzzle_spawn_position != Vector2.ZERO:
		muzzle.global_position = muzzle_spawn_position
	else:
		muzzle.global_position = global_position
	muzzle.play("muzzle")
	muzzle.animation_finished.connect(muzzle.queue_free)


func _spawn_hit_effect() -> void:
	if hit_texture_path.is_empty():
		return

	var texture := load(hit_texture_path) as Texture2D
	if texture == null:
		return

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("hit")
	sf.set_animation_speed("hit", 15)
	sf.set_animation_loop("hit", false)

	for i in range(hit_frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * hit_frame_size.x, 0, hit_frame_size.x, hit_frame_size.y)
		sf.add_frame("hit", atlas)

	var hit := AnimatedSprite2D.new()
	hit.sprite_frames = sf
	hit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hit.modulate = Color(1.0, 0.4, 0.3)

	get_parent().add_child(hit)
	hit.global_position = global_position
	hit.play("hit")
	hit.animation_finished.connect(hit.queue_free)


func _on_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy and enemy.has_method("take_damage") and enemy not in hit_enemies:
		hit_enemies.append(enemy)

		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(damage, Vector2(direction * knockback_force, 0))
		else:
			enemy.take_damage(global_position)

		_spawn_hit_effect()
		_on_hit(enemy)

		print(projectile_name, " hit enemy — destroyed")
		queue_free()


# Override in children for special behavior (burn, freeze, chain, etc.)
func _on_hit(_enemy: Node) -> void:
	pass


func _on_lifetime_expired() -> void:
	if is_inside_tree():
		queue_free()
