class_name DarkTentacleSummon
extends BaseSummon

enum Phase { RISE, HOLD, RETRACT }

var phase: Phase = Phase.RISE
var hold_timer: float = 0.0
var hold_duration: float = 3.0
var damage_tick_timer: float = 0.0
var damage_tick_interval: float = 0.6
var grab_radius: float = 60.0
var _grabbed_enemy: Node2D = null
var _light: PointLight2D = null
var _outline: AnimatedSprite2D = null

# Spritesheet: 1408x192, two rows of 11 frames each = 22 frames
# Frame size: 128x96
const SHEET_FRAME_W = 128
const SHEET_FRAME_H = 96
const COLS = 11
const TOTAL_FRAMES = 22
const RISE_FRAMES = 7
const HOLD_FRAMES = 8
const RETRACT_FRAMES = 7


func _init():
	summon_name = "Dark Tentacle"
	texture_path = "res://assets/effects/combat/summons/darkTentacles/Electric_tentacle-Sheet.png"
	frame_size = Vector2(128, 96)
	animation_speed = 5.0
	damage = 1
	knockback_force = 0.0
	spawn_offset = Vector2(90, -34)
	hitbox_start_frame = 0
	hitbox_end_frame = 0
	match_environment_color = false
	magical_aura_enabled = false


func _ready():
	_setup_animation()

	animated_sprite.flip_h = (direction == -1)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.frame = 0
	animated_sprite.play("rise")
	animated_sprite.animation_finished.connect(_on_animation_finished)

	if hitbox:
		hitbox.monitoring = false

	scale = Vector2(1.5, 1.5)

	_create_light()
	_create_outline()

	print("Dark Tentacle RISING, spawn_offset=", spawn_offset)
	print("Dark Tentacle: PointLight and purple outline added")


func _process(delta: float):
	# Sync outline animation and frame
	if _outline and is_instance_valid(_outline):
		if _outline.animation != animated_sprite.animation:
			_outline.play(animated_sprite.animation)
		if _outline.frame != animated_sprite.frame:
			_outline.frame = animated_sprite.frame

	if phase == Phase.HOLD:
		hold_timer += delta

		# Pulse light during hold
		if _light and is_instance_valid(_light):
			_light.energy = 3.0 + sin(hold_timer * 4.0) * 0.5

		if _grabbed_enemy and is_instance_valid(_grabbed_enemy):
			damage_tick_timer += delta
			if damage_tick_timer >= damage_tick_interval:
				damage_tick_timer = 0.0
				if _grabbed_enemy.has_method("take_damage"):
					_grabbed_enemy.take_damage(global_position)
					print("Tentacle damage tick on ", _grabbed_enemy.name)

		if hold_timer >= hold_duration:
			_start_retract()


func _create_light():
	_light = PointLight2D.new()
	_light.color = Color(0.4, 0.1, 0.6)
	_light.energy = 3.0
	_light.texture_scale = 2.5
	_light.position = Vector2(0, -SHEET_FRAME_H * 0.5)

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
	_outline.play("rise")

	var tween := create_tween().set_loops()
	tween.tween_method(func(val: float) -> void:
		if is_instance_valid(_outline) and _outline.material:
			_outline.material.set_shader_parameter("pulse", val)
	, 0.5, 1.0, 0.3)
	tween.tween_method(func(val: float) -> void:
		if is_instance_valid(_outline) and _outline.material:
			_outline.material.set_shader_parameter("pulse", val)
	, 1.0, 0.5, 0.3)


func _start_retract():
	phase = Phase.RETRACT
	animated_sprite.play("retract")
	print("Dark Tentacle RETRACTING")


func _setup_animation():
	var texture = load(texture_path) as Texture2D
	if not texture:
		push_error("Could not load: " + texture_path)
		return

	var sprite_frames = SpriteFrames.new()

	# Helper to get atlas region for frame index (row/col grid)
	var all_frames: Array[AtlasTexture] = []
	for i in range(TOTAL_FRAMES):
		var col = i % COLS
		var row = i / COLS
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(col * SHEET_FRAME_W, row * SHEET_FRAME_H, SHEET_FRAME_W, SHEET_FRAME_H)
		all_frames.append(atlas)

	# Rise — frames 0-6
	sprite_frames.add_animation("rise")
	sprite_frames.set_animation_speed("rise", animation_speed)
	sprite_frames.set_animation_loop("rise", false)
	for i in range(RISE_FRAMES):
		sprite_frames.add_frame("rise", all_frames[i])

	# Hold — frames 7-14, loops
	sprite_frames.add_animation("hold")
	sprite_frames.set_animation_speed("hold", animation_speed)
	sprite_frames.set_animation_loop("hold", true)
	for i in range(RISE_FRAMES, RISE_FRAMES + HOLD_FRAMES):
		sprite_frames.add_frame("hold", all_frames[i])

	# Retract — frames 15-21
	sprite_frames.add_animation("retract")
	sprite_frames.set_animation_speed("retract", animation_speed)
	sprite_frames.set_animation_loop("retract", false)
	for i in range(RISE_FRAMES + HOLD_FRAMES, TOTAL_FRAMES):
		sprite_frames.add_frame("retract", all_frames[i])

	animated_sprite.sprite_frames = sprite_frames
	frame_count = TOTAL_FRAMES

	print("Dark Tentacle: 128x96 frames (2 rows x 11 cols), rise=", RISE_FRAMES, " hold=", HOLD_FRAMES, " retract=", RETRACT_FRAMES)


func _on_animation_finished():
	match phase:
		Phase.RISE:
			var enemies = get_tree().get_nodes_in_group("enemies")
			var closest_enemy: Node2D = null
			var closest_dist: float = grab_radius

			for enemy in enemies:
				if not is_instance_valid(enemy) or not enemy is CharacterBody2D:
					continue
				var dist = abs(enemy.global_position.x - global_position.x)
				if dist < closest_dist:
					closest_dist = dist
					closest_enemy = enemy

			if closest_enemy:
				_grabbed_enemy = closest_enemy
				phase = Phase.HOLD
				animated_sprite.play("hold")

				if closest_enemy.has_method("apply_root"):
					closest_enemy.apply_root(hold_duration)
				if closest_enemy.has_method("take_damage"):
					closest_enemy.take_damage(global_position)

				print("Dark Tentacle GRABBED ", closest_enemy.name, " — rooted for ", hold_duration, "s")
			else:
				_start_retract()

		Phase.RETRACT:
			queue_free()
