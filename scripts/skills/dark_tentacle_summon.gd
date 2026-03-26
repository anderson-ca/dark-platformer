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

# Spritesheet: 1408x192, actual frame size is 128x192 = 11 frames
const SHEET_FRAME_W = 128
const SHEET_FRAME_H = 192
const TOTAL_FRAMES = 11
const RISE_FRAMES = 4
const HOLD_FRAMES = 4
const RETRACT_FRAMES = 3


func _init():
	summon_name = "Dark Tentacle"
	texture_path = "res://assets/effects/combat/summons/darkTentacles/Electric_tentacle-Sheet.png"
	frame_size = Vector2(SHEET_FRAME_W, SHEET_FRAME_H)
	animation_speed = 10.0
	damage = 1
	knockback_force = 0.0
	spawn_offset = Vector2(65, 0)
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

	print("Dark Tentacle RISING, spawn_offset=", spawn_offset)


func _create_light():
	_light = PointLight2D.new()
	_light.name = "DarkGlow"
	_light.color = Color(0.4, 0.1, 0.6)
	_light.energy = 3.0
	_light.texture_scale = 2.5
	_light.blend_mode = Light2D.BLEND_MODE_ADD

	var size = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0
	for y in range(size):
		for x in range(size):
			var dist = Vector2(x, y).distance_to(center)
			var alpha = clampf(1.0 - dist / radius, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	_light.texture = ImageTexture.create_from_image(img)

	add_child(_light)


func _process(delta: float):
	if phase == Phase.HOLD:
		hold_timer += delta

		if _grabbed_enemy and is_instance_valid(_grabbed_enemy):
			damage_tick_timer += delta
			if damage_tick_timer >= damage_tick_interval:
				damage_tick_timer = 0.0
				if _grabbed_enemy.has_method("take_damage"):
					_grabbed_enemy.take_damage(global_position)
					print("Tentacle damage tick on ", _grabbed_enemy.name)

		if _light:
			_light.energy = 3.0 + sin(hold_timer * 6.0) * 0.5

		if hold_timer >= hold_duration:
			_start_retract()


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

	# Rise — frames 0-3
	sprite_frames.add_animation("rise")
	sprite_frames.set_animation_speed("rise", animation_speed)
	sprite_frames.set_animation_loop("rise", false)
	for i in range(RISE_FRAMES):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * SHEET_FRAME_W, 0, SHEET_FRAME_W, SHEET_FRAME_H)
		sprite_frames.add_frame("rise", atlas)

	# Hold — frames 4-7, loops
	sprite_frames.add_animation("hold")
	sprite_frames.set_animation_speed("hold", animation_speed)
	sprite_frames.set_animation_loop("hold", true)
	for i in range(RISE_FRAMES, RISE_FRAMES + HOLD_FRAMES):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * SHEET_FRAME_W, 0, SHEET_FRAME_W, SHEET_FRAME_H)
		sprite_frames.add_frame("hold", atlas)

	# Retract — frames 8-10
	sprite_frames.add_animation("retract")
	sprite_frames.set_animation_speed("retract", animation_speed)
	sprite_frames.set_animation_loop("retract", false)
	for i in range(RISE_FRAMES + HOLD_FRAMES, TOTAL_FRAMES):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * SHEET_FRAME_W, 0, SHEET_FRAME_W, SHEET_FRAME_H)
		sprite_frames.add_frame("retract", atlas)

	animated_sprite.sprite_frames = sprite_frames
	frame_count = TOTAL_FRAMES

	# Keep default centered=true, no offset — let spawn_offset handle positioning
	animated_sprite.offset = Vector2.ZERO

	print("Dark Tentacle: 128x192 frames, rise=", RISE_FRAMES, " hold=", HOLD_FRAMES, " retract=", RETRACT_FRAMES)


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
