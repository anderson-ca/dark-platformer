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

# Sprite frame size (basic player strips use 240×128 cells)
const FRAME_W = 240
const FRAME_H = 128

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
var _key_jump: bool = false
var _key_jump_just: bool = false
var _key_jump_released: bool = false
var _key_dash_just: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Dust particles
var _dust_run: CPUParticles2D
var _dust_land: CPUParticles2D
var _dust_wall: CPUParticles2D
var _dust_dash: CPUParticles2D
var _was_on_floor: bool = false
var _was_dashing: bool = false


func _ready() -> void:
	_setup_sprite_frames()
	_setup_dust_particles()


func _setup_sprite_frames() -> void:
	var sf := SpriteFrames.new()

	if sf.has_animation("default"):
		sf.remove_animation("default")

	# [anim_name, file_path, frame_count, fps, loop]
	var P := "res://assets/sprites/player/basic_player/"
	var anims := [
		["idle",       P + "1 - Idle.png",     12, 8,  true],
		["run",        P + "2 - Run.png",        8, 10, true],
		["jump",       P + "3 - jump.png",       4, 10, false],
		["fall",       P + "5 - fall.png",       4, 8,  true],
		["dash",       P + "6 - dash.png",       4, 14, false],
		["wall_slide", P + "4 - mid-air.png",    1, 8,  true],
		["death",      P + "15 - death.png",    10, 8,  false],
		["hit",        P + "14 - hit.png",       1, 8,  false],
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
	# Content center x≈118, frame center x=120 → offset.x = 2
	# Feet at y≈79, frame center y=64 → 15px below center
	# Collision 10x20 at y=-1, bottom = 9. offset.y = 9/1.5 - 15 = -9
	animated_sprite.offset = Vector2(2, -9)
	animated_sprite.play("idle")


func _setup_dust_particles() -> void:
	# Angular dust texture — 4x2 elongated rectangle, not a square blob
	var dust_img := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	dust_img.fill(Color.WHITE)
	var dust_tex := ImageTexture.create_from_image(dust_img)

	var feet_y := 9.0  # collision bottom: center(-1) + half-height(10)

	# Shared scale curve: starts full, shrinks to nothing (crisp pop then vanish)
	var shrink_curve := Curve.new()
	shrink_curve.add_point(Vector2(0.0, 1.0))
	shrink_curve.add_point(Vector2(0.4, 0.8))
	shrink_curve.add_point(Vector2(1.0, 0.0))

	# Shared color ramp: light grey, sharp alpha fade at end
	var dust_gradient := Gradient.new()
	dust_gradient.set_offset(0, 0.0)
	dust_gradient.set_color(0, Color(0.85, 0.85, 0.85, 0.7))
	dust_gradient.set_offset(1, 1.0)
	dust_gradient.set_color(1, Color(0.85, 0.85, 0.85, 0.0))

	# Brighter ramp for land burst
	var land_gradient := Gradient.new()
	land_gradient.set_offset(0, 0.0)
	land_gradient.set_color(0, Color(0.85, 0.85, 0.85, 0.8))
	land_gradient.set_offset(1, 1.0)
	land_gradient.set_color(1, Color(0.85, 0.85, 0.85, 0.0))

	# --- 1. Run dust — crisp puffs, few particles, fast fade ---
	_dust_run = CPUParticles2D.new()
	_dust_run.name = "DustRun"
	_dust_run.emitting = false
	_dust_run.amount = 4
	_dust_run.lifetime = 0.2
	_dust_run.explosiveness = 0.3
	_dust_run.texture = dust_tex
	_dust_run.direction = Vector2(0, -0.5)
	_dust_run.spread = 20.0
	_dust_run.initial_velocity_min = 40.0
	_dust_run.initial_velocity_max = 60.0
	_dust_run.gravity = Vector2.ZERO
	_dust_run.damping_min = 8.0
	_dust_run.damping_max = 12.0
	_dust_run.scale_amount_min = 1.5
	_dust_run.scale_amount_max = 3.0
	_dust_run.scale_amount_curve = shrink_curve
	_dust_run.color_ramp = dust_gradient
	_dust_run.position = Vector2(0, feet_y)
	_dust_run.z_index = -1
	add_child(_dust_run)

	# --- 2. Land dust — sharp satisfying POOF, fast in fast out ---
	_dust_land = CPUParticles2D.new()
	_dust_land.name = "DustLand"
	_dust_land.emitting = false
	_dust_land.one_shot = true
	_dust_land.amount = 8
	_dust_land.lifetime = 0.25
	_dust_land.explosiveness = 1.0
	_dust_land.texture = dust_tex
	_dust_land.direction = Vector2(0, -1)
	_dust_land.spread = 45.0
	_dust_land.initial_velocity_min = 60.0
	_dust_land.initial_velocity_max = 120.0
	_dust_land.gravity = Vector2.ZERO
	_dust_land.damping_min = 6.0
	_dust_land.damping_max = 10.0
	_dust_land.scale_amount_min = 2.0
	_dust_land.scale_amount_max = 4.0
	_dust_land.scale_amount_curve = shrink_curve
	_dust_land.color_ramp = land_gradient
	_dust_land.position = Vector2(0, feet_y)
	_dust_land.z_index = -1
	add_child(_dust_land)

	# --- 3. Wall slide dust — tiny fast scrape particles ---
	_dust_wall = CPUParticles2D.new()
	_dust_wall.name = "DustWall"
	_dust_wall.emitting = false
	_dust_wall.amount = 2
	_dust_wall.lifetime = 0.15
	_dust_wall.texture = dust_tex
	_dust_wall.direction = Vector2(0, 1)
	_dust_wall.spread = 15.0
	_dust_wall.initial_velocity_min = 20.0
	_dust_wall.initial_velocity_max = 40.0
	_dust_wall.gravity = Vector2.ZERO
	_dust_wall.damping_min = 10.0
	_dust_wall.damping_max = 15.0
	_dust_wall.scale_amount_min = 1.0
	_dust_wall.scale_amount_max = 2.0
	_dust_wall.scale_amount_curve = shrink_curve
	_dust_wall.color_ramp = dust_gradient
	_dust_wall.position = Vector2(0, 0)
	_dust_wall.z_index = -1
	add_child(_dust_wall)

	# --- 4. Dash burst — sharp directional speed lines ---
	_dust_dash = CPUParticles2D.new()
	_dust_dash.name = "DustDash"
	_dust_dash.emitting = false
	_dust_dash.one_shot = true
	_dust_dash.amount = 8
	_dust_dash.lifetime = 0.2
	_dust_dash.explosiveness = 1.0
	_dust_dash.texture = dust_tex
	_dust_dash.direction = Vector2(-1, 0)
	_dust_dash.spread = 15.0
	_dust_dash.initial_velocity_min = 80.0
	_dust_dash.initial_velocity_max = 150.0
	_dust_dash.gravity = Vector2.ZERO
	_dust_dash.damping_min = 5.0
	_dust_dash.damping_max = 8.0
	_dust_dash.scale_amount_min = 2.0
	_dust_dash.scale_amount_max = 5.0
	_dust_dash.scale_amount_curve = shrink_curve
	_dust_dash.color_ramp = land_gradient
	_dust_dash.position = Vector2(0, 0)
	_dust_dash.z_index = -1
	add_child(_dust_dash)


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
				_key_jump = true
				_key_jump_just = true
			elif not key_event.pressed:
				_key_jump = false
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

	# --- Run dust: emit when running on ground ---
	var is_running: bool = on_floor and abs(velocity.x) > 30 and dash_timer <= 0.0
	_dust_run.emitting = is_running
	if is_running:
		# Emit behind the player (opposite to movement)
		_dust_run.position.x = -sign(velocity.x) * 4.0
		_dust_run.position.y = feet_y

	# --- Land dust: one-shot burst on landing ---
	if landed:
		_dust_land.position = Vector2(0, feet_y)
		_dust_land.emitting = false  # reset one_shot
		_dust_land.emitting = true

	# --- Wall slide dust: emit while wall sliding ---
	_dust_wall.emitting = is_wall_sliding
	if is_wall_sliding:
		# Position at the wall contact side, near player center
		_dust_wall.position = Vector2(wall_dir * 6.0, -2.0)

	# --- Dash dust: one-shot burst at dash start ---
	var is_dashing := dash_timer > 0.0
	if is_dashing and not _was_dashing:
		_dust_dash.direction = Vector2(-dash_direction, 0)
		_dust_dash.position = Vector2(-dash_direction * 4.0, 0)
		_dust_dash.emitting = false  # reset one_shot
		_dust_dash.emitting = true
	_was_dashing = is_dashing
