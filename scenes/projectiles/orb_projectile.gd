extends Area2D

const SPEED := 500.0
const DAMAGE := 1
const KNOCKBACK_FORCE := 150.0
const ORB_FRAME := 128
const ORB_COLS := 5
const ORB_FRAMES := 8

var direction: int = 1
var muzzle_spawn_position: Vector2 = Vector2.ZERO

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
	animated_sprite.modulate = Color(0.8, 0.5, 1.0, 1.0)
	animated_sprite.play("burst")
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Purple outline shader
	var shader := load("res://shaders/purple_outline.gdshader")
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("outline_color", Color(0.6, 0.2, 1.0, 1.0))
	shader_mat.set_shader_parameter("outline_width", 1.5)
	animated_sprite.material = shader_mat

	# Generate light texture
	glow_light.texture = _make_light_texture()

	# Pulse the glow
	var tween := create_tween().set_loops()
	tween.tween_property(glow_light, "energy", 2.0, 0.15)
	tween.tween_property(glow_light, "energy", 1.2, 0.15)

	area_entered.connect(_on_area_entered)

	# Lifetime limit — destroy if no hit after 1.5s
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(1.5).timeout.connect(_on_lifetime_expired)

	print("Orb glow and outline initialized, direction: ", direction)


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
	if enemy and enemy.has_method("take_damage"):
		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(DAMAGE, Vector2(direction * KNOCKBACK_FORCE, 0))
		else:
			enemy.take_damage(global_position)

		# Micro hitstop — brief pause for impact feel
		get_tree().paused = true
		get_tree().create_timer(0.02, true, false, true).timeout.connect(func():
			get_tree().paused = false
		)

		print("Orb hit enemy — destroyed, hitstop 0.02s")
		queue_free()


func _on_animation_finished() -> void:
	queue_free()


func _on_lifetime_expired() -> void:
	print("Orb expired — lifetime reached")
	queue_free()
