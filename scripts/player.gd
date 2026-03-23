extends CharacterBody2D

signal hit_hazard

# Movement
const SPEED = 210.0
const JUMP_VELOCITY = -460.0
const GRAVITY = 1400.0
const MAX_FALL_SPEED = 880.0
const GROUND_ACCELERATION = 1700.0
const AIR_ACCELERATION = 900.0
const GROUND_DRAG = 1900.0
const AIR_DRAG = 180.0

# Coyote time and jump buffer
const COYOTE_TIME = 0.09
const JUMP_BUFFER_TIME = 0.11

# Double jump
const DOUBLE_JUMP_FACTOR = 0.8

# Wall cling + wall jump
const WALL_SLIDE_SPEED = 60.0
const WALL_JUMP_VX = 280.0
const WALL_JUMP_VY = 380.0
const WALL_JUMP_LOCKOUT = 0.2

# Dash
const DASH_SPEED = 500.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 0.6

# Sprite frame size (dark sage strips use 192×192 cells)
const FRAME_W = 192
const FRAME_H = 192

# Respawn
var fall_respawn_y: float = 9999.0
var spawn_point: Vector2 = Vector2.ZERO
var checkpoint: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false

# State
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var has_double_jump: bool = true
var wall_jump_lockout_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 0.0
var has_air_dash: bool = true
var facing: float = 1.0
var is_wall_sliding: bool = false
var wall_dir: float = 0.0

# Raw input tracking
var _key_left: bool = false
var _key_right: bool = false
var _key_jump_just: bool = false
var _key_jump_released: bool = false
var _key_dash_just: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Dust animated sprites
var _dust_run: AnimatedSprite2D
var _dust_land: AnimatedSprite2D
var _dust_wall: AnimatedSprite2D
var _dust_dash: AnimatedSprite2D
var _was_on_floor: bool = false
var _was_dashing: bool = false


func _ready() -> void:
	_setup_sprite_frames()
	_setup_dust_sprites()


func _setup_sprite_frames() -> void:
	var sf := SpriteFrames.new()

	if sf.has_animation("default"):
		sf.remove_animation("default")

	# [anim_name, file_path, frame_count, fps, loop]
	var P := "res://assets/sprites/player/dark_sage/"
	var anims := [
		["idle",       P + "The Evil Sage-Idle Front.png",  9, 8,  true],
		["run",        P + "The Evil Sage-Run.png",         8, 10, true],
		["jump",       P + "The Evil Sage-Jump.png",        4, 10, false],
		["fall",       P + "The Evil Sage-Fall.png",        4, 8,  true],
		["dash",       P + "The Evil Sage-Dash.png",        4, 14, false],
		["wall_slide", P + "The Evil Sage-Wall Slide.png",  4, 8,  true],
		["death",      P + "The Evil Sage-Death.png",       8, 8,  false],
		["hit",        P + "The Evil Sage-hit.png",         2, 8,  false],
	]

	for anim_def in anims:
		var anim_name: String = anim_def[0]
		var file_path: String = anim_def[1]
		var frame_count: int = anim_def[2]
		var fps: float = anim_def[3]
		var looping: bool = anim_def[4]

		var texture := load(file_path) as Texture2D

		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, looping)

		for i in range(frame_count):
			var atlas_tex := AtlasTexture.new()
			atlas_tex.atlas = texture
			atlas_tex.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
			sf.add_frame(anim_name, atlas_tex)

	animated_sprite.sprite_frames = sf
	animated_sprite.scale = Vector2(1.5, 1.5)
	# Dark sage: character at y=107-121 in 192x192 frame, feet at y=121
	# Frame center y=96. Collision bottom = 9px below origin.
	# offset.y = 9/1.5 - (121-96) = 6 - 25 = -19
	animated_sprite.offset = Vector2(0, -19)
	animated_sprite.play("idle")


func _setup_dust_sprites() -> void:
	var E := "res://assets/effects/"
	var feet_y := 9.0  # collision bottom: center(-1) + half-height(10)
	var DUST_FRAME := 128

	# Helper: build SpriteFrames from a horizontal strip of 128x128 frames
	var make_dust_frames := func(path: String, anim_name: String, frame_count: int, fps: float, loop: bool) -> SpriteFrames:
		var sf := SpriteFrames.new()
		if sf.has_animation("default"):
			sf.remove_animation("default")
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
		var tex := load(path) as Texture2D
		for i in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * DUST_FRAME, 0, DUST_FRAME, DUST_FRAME)
			sf.add_frame(anim_name, atlas)
		return sf

	# Helper: create a dust AnimatedSprite2D
	var make_dust_sprite := func(node_name: String, sf: SpriteFrames, pos: Vector2, sc: Vector2) -> AnimatedSprite2D:
		var sprite := AnimatedSprite2D.new()
		sprite.name = node_name
		sprite.sprite_frames = sf
		sprite.centered = true
		sprite.position = pos
		sprite.z_index = -1
		sprite.scale = sc
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.visible = false
		add_child(sprite)
		return sprite

	# 1. Run dust — jump_land_dust.png at 60% scale, looping, 10 fps
	var run_sf: SpriteFrames = make_dust_frames.call(E + "jump_land_dust.png", "run", 5, 10.0, true)
	_dust_run = make_dust_sprite.call("DustRun", run_sf, Vector2(0, feet_y), Vector2(0.1, 0.1))

	# 2. Land dust — jump_land_dust.png, one-shot, 12 fps
	var land_sf: SpriteFrames = make_dust_frames.call(E + "jump_land_dust.png", "land", 5, 12.0, false)
	_dust_land = make_dust_sprite.call("DustLand", land_sf, Vector2(0, feet_y), Vector2(0.125, 0.125))
	_dust_land.animation_finished.connect(_on_land_dust_finished)

	# 3. Wall dust — wall_dust.png, looping, 10 fps
	var wall_sf: SpriteFrames = make_dust_frames.call(E + "wall_dust.png", "wall", 6, 10.0, true)
	_dust_wall = make_dust_sprite.call("DustWall", wall_sf, Vector2.ZERO, Vector2(0.125, 0.125))

	# 4. Dash dust — floor_dash_dust.png, one-shot, 15 fps
	var dash_sf: SpriteFrames = make_dust_frames.call(E + "floor_dash_dust.png", "dash", 7, 15.0, false)
	_dust_dash = make_dust_sprite.call("DustDash", dash_sf, Vector2(0, feet_y), Vector2(0.125, 0.125))
	_dust_dash.animation_finished.connect(_on_dash_dust_finished)


func _on_land_dust_finished() -> void:
	_dust_land.visible = false


func _on_dash_dust_finished() -> void:
	_dust_dash.visible = false


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	var code := key_event.physical_keycode

	match code:
		KEY_A:
			_key_left = key_event.pressed
		KEY_D:
			_key_right = key_event.pressed
		KEY_SPACE:
			if key_event.pressed and not key_event.echo:
				_key_jump_just = true
			elif not key_event.pressed:
				_key_jump_released = true
		KEY_SHIFT:
			if key_event.pressed and not key_event.echo:
				_key_dash_just = true


func reset_abilities() -> void:
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	has_double_jump = true
	wall_jump_lockout_timer = 0.0
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	has_air_dash = true
	velocity = Vector2.ZERO


func respawn() -> void:
	if has_checkpoint:
		global_position = checkpoint
	else:
		global_position = spawn_point
	reset_abilities()


func set_spawn(pos: Vector2) -> void:
	spawn_point = pos
	has_checkpoint = false
	checkpoint = Vector2.ZERO


func activate_checkpoint(pos: Vector2) -> void:
	checkpoint = pos
	has_checkpoint = true


func _physics_process(delta: float) -> void:
	# Consume one-shot input flags
	var jump_just_pressed := _key_jump_just
	var jump_just_released := _key_jump_released
	var dash_just_pressed := _key_dash_just
	_key_jump_just = false
	_key_jump_released = false
	_key_dash_just = false

	# Fall respawn check
	if global_position.y > fall_respawn_y:
		hit_hazard.emit()
		return

	var on_floor := is_on_floor()
	var on_wall := is_on_wall()
	var input_dir := 0.0
	if _key_right:
		input_dir += 1.0
	if _key_left:
		input_dir -= 1.0
	var wall_normal := get_wall_normal() if on_wall else Vector2.ZERO

	# --- Timers ---
	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	wall_jump_lockout_timer = max(wall_jump_lockout_timer - delta, 0.0)
	dash_timer = max(dash_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

	# --- Landing resets ---
	if on_floor:
		coyote_timer = COYOTE_TIME
		has_double_jump = true
		has_air_dash = true

	# --- Dashing ---
	if dash_timer > 0.0:
		velocity.x = dash_direction * DASH_SPEED
		if not on_floor:
			velocity.y = min(velocity.y, 30.0)
		move_and_slide()
		_was_on_floor = is_on_floor()
		_update_animation()
		_update_dust(false)
		return

	# --- Dash input ---
	if dash_just_pressed and dash_cooldown_timer <= 0.0:
		if on_floor or has_air_dash:
			dash_timer = DASH_DURATION
			dash_cooldown_timer = DASH_COOLDOWN
			dash_direction = facing
			if not on_floor:
				has_air_dash = false
			velocity.x = dash_direction * DASH_SPEED
			if not on_floor:
				velocity.y = min(velocity.y, 30.0)
			move_and_slide()
			_was_on_floor = is_on_floor()
			_update_animation()
			_update_dust(false)
			return

	# --- Gravity ---
	if not on_floor:
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)

	# --- Wall slide ---
	is_wall_sliding = false
	wall_dir = 0.0
	if on_wall and not on_floor and velocity.y > 0.0:
		if (input_dir > 0.0 and wall_normal.x < 0.0) or (input_dir < 0.0 and wall_normal.x > 0.0):
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)
			has_double_jump = true
			is_wall_sliding = true
			wall_dir = -wall_normal.x

	# --- Jump buffer ---
	if jump_just_pressed:
		jump_buffer_timer = JUMP_BUFFER_TIME

	# --- Jump logic ---
	var can_coyote_jump := coyote_timer > 0.0
	var can_wall_jump := on_wall and not on_floor

	if jump_buffer_timer > 0.0:
		if can_coyote_jump:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
		elif can_wall_jump:
			velocity.y = -WALL_JUMP_VY
			velocity.x = wall_normal.x * WALL_JUMP_VX
			wall_jump_lockout_timer = WALL_JUMP_LOCKOUT
			jump_buffer_timer = 0.0
			has_double_jump = true
			coyote_timer = 0.0
		elif has_double_jump and not on_floor:
			velocity.y = JUMP_VELOCITY * DOUBLE_JUMP_FACTOR
			has_double_jump = false
			jump_buffer_timer = 0.0

	# --- Jump buffer on landing ---
	if on_floor and jump_buffer_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0

	# --- Variable jump height ---
	if jump_just_released and velocity.y < 0.0:
		velocity.y *= 0.5

	# --- Horizontal movement ---
	if wall_jump_lockout_timer <= 0.0:
		var accel := GROUND_ACCELERATION if on_floor else AIR_ACCELERATION
		var drag := GROUND_DRAG if on_floor else AIR_DRAG

		if input_dir != 0.0:
			velocity.x = move_toward(velocity.x, input_dir * SPEED, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, drag * delta)

	# --- Facing direction ---
	if input_dir != 0.0:
		facing = input_dir

	move_and_slide()

	# --- Landing detection for dust burst ---
	var landed := is_on_floor() and not _was_on_floor
	_was_on_floor = is_on_floor()

	_update_animation()
	_update_dust(landed)


func _update_animation() -> void:
	# Flip based on facing
	if is_wall_sliding:
		animated_sprite.flip_h = wall_dir > 0
		# Nudge sprite toward wall to close visual gap (6px)
		animated_sprite.position.x = wall_dir * 6.0
	else:
		animated_sprite.flip_h = facing < 0.0
		animated_sprite.position.x = 0.0

	# Pick animation
	var anim := "idle"
	if dash_timer > 0.0:
		anim = "dash"
	elif is_wall_sliding:
		anim = "wall_slide"
	elif not is_on_floor():
		if velocity.y < -40:
			anim = "jump"
		else:
			anim = "fall"
	elif abs(velocity.x) > 30:
		anim = "run"

	if animated_sprite.animation != anim or not animated_sprite.is_playing():
		animated_sprite.play(anim)


func _update_dust(landed: bool) -> void:
	var on_floor := is_on_floor()
	var feet_y := 9.0

	# --- Run dust: play when running on ground, not dashing ---
	var is_running: bool = on_floor and abs(velocity.x) > 30 and dash_timer <= 0.0
	if is_running:
		_dust_run.flip_h = velocity.x > 0.0
		_dust_run.position = Vector2(-sign(velocity.x) * 4.0, feet_y)
		if not _dust_run.visible:
			_dust_run.visible = true
			_dust_run.play("run")
	else:
		if _dust_run.visible:
			_dust_run.visible = false
			_dust_run.stop()

	# --- Land dust: one-shot on landing ---
	if landed:
		_dust_land.position = Vector2(0, feet_y)
		_dust_land.visible = true
		_dust_land.frame = 0
		_dust_land.play("land")

	# --- Wall dust: loop while wall sliding ---
	if is_wall_sliding:
		var wn := get_wall_normal()
		_dust_wall.position = Vector2(-wn.x * 6.0, -2.0)
		_dust_wall.flip_h = wn.x > 0.0
		if not _dust_wall.visible:
			_dust_wall.visible = true
			_dust_wall.play("wall")
	else:
		if _dust_wall.visible:
			_dust_wall.visible = false
			_dust_wall.stop()

	# --- Dash dust: one-shot at dash start, at feet ---
	var is_dashing := dash_timer > 0.0
	if is_dashing and not _was_dashing and on_floor:
		_dust_dash.flip_h = dash_direction > 0.0
		_dust_dash.position = Vector2(-dash_direction * 8.0, feet_y)
		_dust_dash.visible = true
		_dust_dash.frame = 0
		_dust_dash.play("dash")
	_was_dashing = is_dashing
