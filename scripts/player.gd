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
var is_attacking: bool = false
var _combo_stage: int = 0  # 0=none, 1=attack1 playing, 2=attack2 playing
var _combo_window: bool = false
var _combo_timer: float = 0.0
const COMBO_WINDOW_TIME := 0.4
var is_shielding: bool = false
var _attack_hitbox: Area2D
var _shield_zone: Area2D
const SHIELD_REPEL_FORCE := 200.0
const SHIELD_ZONE_WIDTH := 45.0
var _shield_phase: String = ""  # "up", "hold", "down"
var is_shockwaving: bool = false
var is_dead: bool = false
var is_invincible: bool = false
var _is_taking_hit: bool = false
var shockwave_cooldown_timer: float = 0.0
const SHOCKWAVE_COOLDOWN := 2.0
const MAX_HEALTH := 3
var current_health: int = MAX_HEALTH

# Raw input tracking
var _key_left: bool = false
var _key_right: bool = false
var _key_jump_just: bool = false
var _key_jump_released: bool = false
var _key_dash_just: bool = false
var _key_attack_just: bool = false
var _key_shield_held: bool = false
var _key_shockwave_just: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Dust animated sprites
var _dust_run: AnimatedSprite2D
var _dust_land: AnimatedSprite2D
var _dust_wall: AnimatedSprite2D
var _dust_dash: AnimatedSprite2D
var _was_on_floor: bool = false
var _was_dashing: bool = false


func _ready() -> void:
	add_to_group("player")
	# Player on layer 1, collides with ground (layers 1+3) but NOT enemies (layer 2)
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, true)
	_setup_sprite_frames()
	_setup_dust_sprites()
	_setup_player_light()
	_setup_attack_hitbox()
	_setup_shield_zone()
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _setup_sprite_frames() -> void:
	var sf := SpriteFrames.new()

	if sf.has_animation("default"):
		sf.remove_animation("default")

	# [anim_name, file_path, frame_count, fps, loop]
	var P := "res://assets/sprites/player/sage/"
	var anims := [
		["idle",        P + "The Sage-Idle Front.png",  9, 8,  true],
		["run",         P + "The Sage-Run.png",         8, 10, true],
		["jump",        P + "The Sage-Jump.png",        4, 10, false],
		["fall",        P + "The Sage-Fall.png",        4, 8,  true],
		["dash",        P + "The Sage-Dash.png",        4, 14, false],
		["wall_slide",  P + "The Sage-Wall Slide.png",  4, 8,  true],
		["death",       P + "The Sage-Death.png",       8, 8,  false],
		["hit",         P + "The Sage-hit.png",         2, 8,  false],
		["attack1",     P + "The Sage-Orb attack.png",  8, 12, false, 0],
		["attack",      P + "The Sage-Orb attack.png", 16, 12, false, 0],
		["shield_up",   P + "The Sage-Shield up.png",    4, 10, false],
		["shield_hold", P + "The Sage-shield hold.png",  8, 10, true],
		["shield_down", P + "The Sage-shield down.png",  4, 10, false],
		["shockwave",   P + "The Sage-Shockwave.png",   14, 12, false],
	]

	for anim_def in anims:
		var anim_name: String = anim_def[0]
		var file_path: String = anim_def[1]
		var frame_count: int = anim_def[2]
		var fps: float = anim_def[3]
		var looping: bool = anim_def[4]
		var start_frame: int = anim_def[5] if anim_def.size() > 5 else 0

		var texture := load(file_path) as Texture2D

		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, looping)

		for i in range(frame_count):
			var atlas_tex := AtlasTexture.new()
			atlas_tex.atlas = texture
			atlas_tex.region = Rect2((start_frame + i) * FRAME_W, 0, FRAME_W, FRAME_H)
			sf.add_frame(anim_name, atlas_tex)

	animated_sprite.sprite_frames = sf
	for anim_def in anims:
		print("  ", anim_def[0], ": ", anim_def[2], " frames @ ", anim_def[3], " FPS -> ", anim_def[1])
	print("Combo: attack1 (8 frames, single orb) | full attack (16 frames, both orbs) | window=", COMBO_WINDOW_TIME, "s")
	animated_sprite.scale = Vector2(1.5, 1.5)
	# Sage: character at y=107-121 in 192x192 frame, feet at y=121
	# Frame center y=96. Collision bottom = 9px below origin.
	# offset.y = 9/1.5 - (121-96) = 6 - 25 = -19
	animated_sprite.offset = Vector2(0, -19)
	animated_sprite.play("idle")


func _setup_player_light() -> void:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - dist / radius, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var light_tex := ImageTexture.create_from_image(img)

	var light := PointLight2D.new()
	light.name = "PlayerLight"
	light.color = Color(1.0, 0.95, 0.8)
	light.energy = 1.3
	light.texture = light_tex
	light.texture_scale = 2.5
	light.position = Vector2(0, -5)  # roughly center of player body
	light.shadow_enabled = false
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)
	print("PlayerLight: energy=1.3, scale=2.5, color=", light.color)


func _setup_attack_hitbox() -> void:
	_attack_hitbox = Area2D.new()
	_attack_hitbox.name = "AttackHitbox"
	_attack_hitbox.collision_layer = 0
	_attack_hitbox.collision_mask = 4  # detect enemy hitbox layer
	_attack_hitbox.monitoring = false

	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 20)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(20, -5)  # in front of player
	_attack_hitbox.add_child(col)
	add_child(_attack_hitbox)
	_attack_hitbox.area_entered.connect(_on_attack_hit_enemy)


func _setup_shield_zone() -> void:
	_shield_zone = Area2D.new()
	_shield_zone.name = "ShieldZone"
	_shield_zone.collision_layer = 0
	_shield_zone.collision_mask = 2  # detect enemy bodies (layer 2)
	_shield_zone.monitoring = false

	var shape := RectangleShape2D.new()
	shape.size = Vector2(SHIELD_ZONE_WIDTH, 30)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(SHIELD_ZONE_WIDTH / 2.0, -8)  # in front of player
	_shield_zone.add_child(col)
	add_child(_shield_zone)
	print("ShieldZone: ", SHIELD_ZONE_WIDTH, "px wide, repel force=", SHIELD_REPEL_FORCE)


func _repel_enemies_from_shield() -> void:
	if not _shield_zone.monitoring:
		return
	for body in _shield_zone.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("apply_repel"):
			var dir: float = sign(body.global_position.x - global_position.x)
			if dir == 0.0:
				dir = facing
			body.apply_repel(dir, SHIELD_REPEL_FORCE)


func _on_attack_hit_enemy(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy.has_method("take_damage"):
		enemy.take_damage(global_position)


func take_damage(from_position: Vector2) -> void:
	if is_dead or is_invincible:
		return
	if is_shielding:
		print("Shield BLOCKED attack!")
		var ghouls := get_tree().get_nodes_in_group("enemies")
		for enemy in ghouls:
			if enemy.has_method("take_knockback"):
				var dist := global_position.distance_to(enemy.global_position)
				if dist < 60.0:
					enemy.take_knockback(global_position)
		return
	current_health -= 1
	print("Player hit! health=", current_health, "/", MAX_HEALTH)
	if current_health <= 0:
		_play_death()
	else:
		_play_hit(from_position)


func _play_hit(from_position: Vector2) -> void:
	_is_taking_hit = true
	is_invincible = true
	is_attacking = false
	_combo_stage = 0
	_combo_window = false
	is_shielding = false
	_shield_phase = ""
	_shield_zone.monitoring = false
	is_shockwaving = false
	_attack_hitbox.monitoring = false

	# Knockback away from damage source
	var kb_dir: float = sign(global_position.x - from_position.x)
	if kb_dir == 0.0:
		kb_dir = 1.0
	velocity.x = kb_dir * 120.0
	velocity.y = -80.0

	animated_sprite.play("hit")
	print("Player hit animation: 2 frames @ 8 FPS, invincible for 0.5s")

	# Wait for hit animation
	await get_tree().create_timer(0.25).timeout
	_is_taking_hit = false
	if is_dead:
		return

	# Blink for remaining invincibility
	var blink_end := 0.5  # total blink time after hit anim
	var blink_elapsed := 0.0
	while blink_elapsed < blink_end:
		animated_sprite.visible = not animated_sprite.visible
		await get_tree().create_timer(0.06).timeout
		blink_elapsed += 0.06
		if is_dead:
			animated_sprite.visible = true
			return

	animated_sprite.visible = true
	is_invincible = false


func _play_death() -> void:
	is_dead = true
	is_attacking = false
	_combo_stage = 0
	_combo_window = false
	is_shielding = false
	is_shockwaving = false
	_attack_hitbox.monitoring = false
	_shield_zone.monitoring = false
	velocity = Vector2.ZERO
	animated_sprite.play("death")
	print("Player death: 8 frames @ 8 FPS, waiting 1.5s before respawn")
	await get_tree().create_timer(1.5).timeout
	is_dead = false
	hit_hazard.emit()


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
	# Mouse buttons — attack / shield / shockwave
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_key_attack_just = true
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_key_shield_held = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			_key_shockwave_just = true
		return

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
		KEY_J:
			if key_event.pressed and not key_event.echo:
				_key_attack_just = true
		KEY_K:
			_key_shield_held = key_event.pressed
		KEY_L:
			if key_event.pressed and not key_event.echo:
				_key_shockwave_just = true


func _on_animation_finished() -> void:
	if animated_sprite.animation == "attack1":
		_attack_hitbox.monitoring = false
		# Single tap finished — open combo window for double tap
		_combo_window = true
		_combo_timer = COMBO_WINDOW_TIME
		is_attacking = false  # brief movement window between taps
	elif animated_sprite.animation == "attack":
		# Full combo attack finished
		is_attacking = false
		_combo_stage = 0
		_combo_window = false
		_attack_hitbox.monitoring = false
	elif animated_sprite.animation == "shield_up":
		_shield_phase = "hold"
		animated_sprite.play("shield_hold")
	elif animated_sprite.animation == "shield_down":
		is_shielding = false
		_shield_phase = ""
	elif animated_sprite.animation == "shockwave":
		is_shockwaving = false


func reset_abilities() -> void:
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	has_double_jump = true
	wall_jump_lockout_timer = 0.0
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	has_air_dash = true
	is_attacking = false
	_combo_stage = 0
	_combo_window = false
	_combo_timer = 0.0
	is_shielding = false
	_shield_phase = ""
	is_shockwaving = false
	is_dead = false
	is_invincible = false
	_is_taking_hit = false
	current_health = MAX_HEALTH
	shockwave_cooldown_timer = 0.0
	velocity = Vector2.ZERO
	animated_sprite.visible = true


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
	if is_dead or _is_taking_hit:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DRAG * delta)
		move_and_slide()
		return

	# Consume one-shot input flags
	var jump_just_pressed := _key_jump_just
	var jump_just_released := _key_jump_released
	var dash_just_pressed := _key_dash_just
	var attack_just_pressed := _key_attack_just
	var shield_held := _key_shield_held
	var shockwave_just_pressed := _key_shockwave_just
	_key_jump_just = false
	_key_jump_released = false
	_key_dash_just = false
	_key_attack_just = false
	_key_shockwave_just = false

	# Timers
	shockwave_cooldown_timer = max(shockwave_cooldown_timer - delta, 0.0)
	if _combo_window:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_window = false
			_combo_stage = 0

	# Fall respawn check
	if global_position.y > fall_respawn_y:
		hit_hazard.emit()
		return

	# --- Shockwave (highest priority except death) ---
	if shockwave_just_pressed and is_on_floor() and not is_shockwaving and shockwave_cooldown_timer <= 0.0:
		is_shockwaving = true
		is_attacking = false
		is_shielding = false
		_shield_phase = ""
		_shield_zone.monitoring = false
		shockwave_cooldown_timer = SHOCKWAVE_COOLDOWN
		velocity.x = 0.0
		animated_sprite.play("shockwave")

	if is_shockwaving:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DRAG * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
		move_and_slide()
		_was_on_floor = is_on_floor()
		return

	# --- Shield ---
	if shield_held and is_on_floor() and not is_attacking and dash_timer <= 0.0:
		if not is_shielding:
			is_shielding = true
			_shield_phase = "up"
			animated_sprite.play("shield_up")
			# Activate shield zone facing player direction
			_shield_zone.scale.x = facing
			_shield_zone.monitoring = true
	elif is_shielding and not shield_held:
		# Release shield
		_shield_phase = "down"
		animated_sprite.play("shield_down")
		_shield_zone.monitoring = false

	if is_shielding:
		# Repel enemies each frame
		_repel_enemies_from_shield()
		# No movement while shielding — stationary
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
		move_and_slide()
		_was_on_floor = is_on_floor()
		animated_sprite.flip_h = facing < 0.0
		animated_sprite.position.x = 0.0
		return

	# --- Attack / Combo ---
	if attack_just_pressed and is_on_floor() and dash_timer <= 0.0:
		if _combo_window and _combo_stage == 1:
			# Double tap: play full attack (both orbs)
			is_attacking = true
			_combo_stage = 2
			_combo_window = false
			velocity.x = 0.0
			animated_sprite.play("attack")
			_attack_hitbox.scale.x = facing
			_attack_hitbox.monitoring = true
		elif not is_attacking and _combo_stage == 0:
			# Single tap: quick attack (first orb only)
			is_attacking = true
			_combo_stage = 1
			_combo_window = false
			velocity.x = 0.0
			animated_sprite.play("attack1")
			_attack_hitbox.scale.x = facing
			_attack_hitbox.monitoring = true

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DRAG * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
		move_and_slide()
		_was_on_floor = is_on_floor()
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
