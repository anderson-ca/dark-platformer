class_name DarkEyesSummon
extends BaseSummon

var _light: PointLight2D = null
var _outline: AnimatedSprite2D = null

# Spritesheet: 1600x576, 10 frames as vertical slices across FULL height
# Each frame = 160x576 (both rows combined — tentacles on top, eyes on bottom)
const SHEET_W = 1600
const SHEET_H = 576
const FRAME_W = 160
const FRAME_H = 576
const FRAME_COUNT = 10


func _init():
	summon_name = "Dark Eyes"
	texture_path = "res://assets/effects/combat/summons/darkEyes/Dark_eyes-Sheet.png"
	frame_size = Vector2(FRAME_W, FRAME_H)
	animation_speed = 10.0
	damage = 2
	knockback_force = 100.0
	spawn_offset = Vector2(70, 5)
	hitbox_start_frame = 3
	hitbox_end_frame = 7
	match_environment_color = false
	magical_aura_enabled = false


func _ready():
	_setup_animation()

	animated_sprite.flip_h = (direction == -1)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.frame = 0
	animated_sprite.play("summon")
	animated_sprite.animation_finished.connect(_on_animation_finished)

	scale = Vector2(2.0, 2.0)

	_create_light()
	_create_outline()

	print("Dark Eyes: image=", SHEET_W, "x", SHEET_H, " frame_size=", FRAME_W, "x", FRAME_H, " frame_count=", FRAME_COUNT)
	print("Dark Eyes summoned")


func _process(_delta: float):
	# Sync outline animation and frame
	if _outline and is_instance_valid(_outline):
		if _outline.frame != animated_sprite.frame:
			_outline.frame = animated_sprite.frame

	# Pulse light
	if _light and is_instance_valid(_light):
		var t = Time.get_ticks_msec() / 1000.0
		_light.energy = 3.0 + sin(t * 4.0) * 0.5

	# Frame-synced hitbox
	if hitbox:
		var f = animated_sprite.frame
		hitbox.monitoring = (f >= hitbox_start_frame and f <= hitbox_end_frame)


func _setup_animation():
	var texture = load(texture_path) as Texture2D
	if not texture:
		push_error("Could not load: " + texture_path)
		return

	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("summon")
	sprite_frames.set_animation_speed("summon", animation_speed)
	sprite_frames.set_animation_loop("summon", false)

	for i in range(FRAME_COUNT):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		sprite_frames.add_frame("summon", atlas)
		print("Dark Eyes frame ", i, " region=", atlas.region)

	animated_sprite.sprite_frames = sprite_frames
	frame_count = FRAME_COUNT


func _create_light():
	_light = PointLight2D.new()
	_light.color = Color(0.4, 0.1, 0.6)
	_light.energy = 3.0
	_light.texture_scale = 2.5
	_light.position = Vector2(0, -FRAME_H * 0.3)

	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var dist := Vector2(x, y).distance_to(center) / 32.0
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	_light.texture = ImageTexture.create_from_image(img)
	add_child(_light)


func _create_outline():
	_outline = AnimatedSprite2D.new()
	_outline.name = "AuraOutline"
	_outline.sprite_frames = animated_sprite.sprite_frames
	_outline.flip_h = animated_sprite.flip_h
	_outline.z_index = -1
	_outline.centered = animated_sprite.centered
	_outline.offset = animated_sprite.offset
	_outline.position = animated_sprite.position
	_outline.scale = animated_sprite.scale

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.5, 0.1, 0.7, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.5;
uniform float pulse : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	float outline = 0.0;

	outline += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;

	outline = min(outline, 1.0);

	vec4 tex_color = texture(TEXTURE, UV);
	float outline_mask = outline * (1.0 - tex_color.a);

	vec4 glow = outline_color * outline_mask * pulse;
	glow.a *= 0.8;

	COLOR = glow;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("outline_color", Color(0.5, 0.1, 0.7, 1.0))
	mat.set_shader_parameter("outline_width", 1.5)
	_outline.material = mat

	add_child(_outline)
	_outline.play("summon")

	var tween := create_tween().set_loops()
	tween.tween_method(func(val: float) -> void:
		if is_instance_valid(_outline) and _outline.material:
			_outline.material.set_shader_parameter("pulse", val)
	, 0.5, 1.0, 0.3)
	tween.tween_method(func(val: float) -> void:
		if is_instance_valid(_outline) and _outline.material:
			_outline.material.set_shader_parameter("pulse", val)
	, 1.0, 0.5, 0.3)


func _on_animation_finished() -> void:
	queue_free()
