extends Area2D

const SPEED := 200.0
const DAMAGE := 1
const KNOCKBACK_FORCE := 150.0
const ORB_FRAME := 128
const ORB_COLS := 5
const ORB_FRAMES := 8

var direction: int = 1
var hit_enemies: Array = []

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var glow_light: PointLight2D = $GlowLight


func _ready() -> void:
	var orb_tex := load("res://assets/effects/combat/attack/dark_power.png") as Texture2D

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("burst")
	sf.set_animation_speed("burst", 15.0)
	sf.set_animation_loop("burst", false)
	for i in range(ORB_FRAMES):
		var col := i % ORB_COLS
		var row := i / ORB_COLS
		var atlas := AtlasTexture.new()
		atlas.atlas = orb_tex
		atlas.region = Rect2(col * ORB_FRAME, row * ORB_FRAME, ORB_FRAME, ORB_FRAME)
		sf.add_frame("burst", atlas)

	animated_sprite.sprite_frames = sf
	animated_sprite.flip_h = (direction == -1)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.play("burst")
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Purple PointLight — illuminates environment like a purple light bulb
	if glow_light:
		glow_light.texture = _make_light_texture()
		glow_light.color = Color(0.7, 0.2, 1.0, 1.0)
		glow_light.energy = 2.2
		glow_light.texture_scale = 1.5

	area_entered.connect(_on_area_entered)
	print("Orb purple light initialized, direction: ", direction)


func _make_light_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - dist / radius, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta


func _on_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy and enemy.has_method("take_damage") and enemy not in hit_enemies:
		hit_enemies.append(enemy)
		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(DAMAGE, Vector2(direction * KNOCKBACK_FORCE, 0))
		else:
			enemy.take_damage(global_position)
		print("Orb hit enemy: ", enemy.name)



func _on_animation_finished() -> void:
	queue_free()
