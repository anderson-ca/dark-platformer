extends CharacterBody2D

enum State { IDLE, WAKE, CHASE, ATTACK, HIT, DEATH, RECOVER, REPOSITION, PATROL }

const SPEED := 60.0
const GRAVITY := 1400.0
const MAX_FALL_SPEED := 880.0
const DETECTION_RANGE := 300.0
const ATTACK_RANGE := 40.0
const HIT_STUN_TIME := 0.3
const FRAME_W := 62
const FRAME_H := 33
const MAX_CONSECUTIVE_ATTACKS := 2
const ATTACK_COOLDOWN := 1.5
const RECOVER_TIME := 1.0
const REPOSITION_DISTANCE := 80.0
const RECOVER_SPEED := 40.0
const SOFT_SEPARATION_DIST := 35.0
const SOFT_SEPARATION_FORCE := 80.0
const PATROL_SPEED := 40.0
const PATROL_EDGE_PAUSE := 0.7
var _patrol_pause_timer: float = 0.0
var _patrol_dir: float = 1.0
var is_dead: bool = false

var state: State = State.IDLE
var health: int = 3
var facing: float = -1.0
var hit_stun_timer: float = 0.0
var attack_count: int = 0
var attack_cooldown_timer: float = 0.0
var recover_timer: float = 0.0
var reposition_timer: float = 0.0
var _player: CharacterBody2D = null
var _has_dealt_damage: bool = false
var _shield_blocked_timer: float = 0.0
const SHIELD_BACK_OFF_TIME := 1.5
var is_stunned: bool = false
var stun_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION := 400.0

# Petrify
var is_petrified: bool = false
var petrify_timer: float = 0.0
var _petrify_overlay: Sprite2D = null
var _petrify_original_material: Material = null
var _petrify_damage_multiplier: float = 1.0

# Burn
var is_burning: bool = false
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
var burn_damage_per_tick: int = 1
var _burn_tween: Tween = null

# Root
var is_rooted: bool = false
var root_timer: float = 0.0

# Visibility — rim light + eye light
var _eye_light: PointLight2D = null
var _rim_material: ShaderMaterial = null
var _telegraph_tween: Tween = null
var _revealed: bool = false
var floor_check_left: RayCast2D = null
var floor_check_right: RayCast2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	add_to_group("enemies")
	_setup_animations()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_area.body_entered.connect(_on_attack_area_body_entered)

	# Find player in scene
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		var world := get_parent()
		while world:
			if world.has_node("Player"):
				_player = world.get_node("Player")
				break
			world = world.get_parent()

	# Floor check raycasts for ledge detection
	floor_check_left = RayCast2D.new()
	floor_check_left.name = "FloorCheckLeft"
	floor_check_left.position = Vector2(-15, 5)
	floor_check_left.target_position = Vector2(0, 20)
	floor_check_left.enabled = true
	floor_check_left.collision_mask = 0
	floor_check_left.set_collision_mask_value(3, true)
	add_child(floor_check_left)

	floor_check_right = RayCast2D.new()
	floor_check_right.name = "FloorCheckRight"
	floor_check_right.position = Vector2(15, 5)
	floor_check_right.target_position = Vector2(0, 20)
	floor_check_right.enabled = true
	floor_check_right.collision_mask = 0
	floor_check_right.set_collision_mask_value(3, true)
	add_child(floor_check_right)

	_create_rim_light()
	_create_eye_light()

	# Verify alignment at runtime
	var col_shape := $CollisionShape2D
	var col_rect := col_shape.shape as RectangleShape2D
	var col_bottom: float = col_shape.position.y + col_rect.size.y / 2.0
	print("Ghoul collision: pos=", col_shape.position, " size=", col_rect.size, " bottom_y=", col_bottom)
	print("Ghoul sprite: pos=", animated_sprite.position, " (adjust Y to move feet up/down)")
	if _rim_material:
		print("Ghoul rim shader: rim_color=", _rim_material.get_shader_parameter("rim_color"), " rim_width=", _rim_material.get_shader_parameter("rim_width"))

	# Verify hitbox size and collision layer
	var hitbox_shape := $Hitbox/CollisionShape2D
	var hitbox_rect := hitbox_shape.shape as RectangleShape2D
	var hitbox_area := $Hitbox as Area2D
	print("Ghoul hitbox: size=", hitbox_rect.size, " pos=", hitbox_shape.position, " collision_layer=", hitbox_area.collision_layer)

	print("Ghoul ready: health=", health, " soft_sep=", SOFT_SEPARATION_DIST, "px force=", SOFT_SEPARATION_FORCE)
	print("  Shield range=", 45, "px repel=", 15, " | max_attacks=", MAX_CONSECUTIVE_ATTACKS, " cooldown=", ATTACK_COOLDOWN, "s")
	print("  State flow: IDLE -> WAKE -> CHASE -> ATTACK (x", MAX_CONSECUTIVE_ATTACKS, ") -> RECOVER -> REPOSITION -> CHASE")


func _setup_animations() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var P := "res://assets/sprites/enemies/Ghoul/"
	var anims := [
		["idle",   P + "static idle.png",  1, 8,  true],
		["walk",   P + "Walk.png",          9, 10, true],
		["attack", P + "Attack.png",        7, 10, false],
		["hit",    P + "hit.png",           4, 10, false],
		["death",  P + "death.png",         8, 8,  false],
		["spawn",  P + "spawn.png",        11, 10, false],
		["wake",   P + "Wake.png",          4, 8,  false],
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
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Petrify check — FIRST, before anything else
	if is_petrified:
		petrify_timer -= delta
		velocity = Vector2.ZERO
		if petrify_timer <= 0.0:
			_end_petrify()
		move_and_slide()
		return

	# Burn tick — runs alongside normal AI
	if is_burning:
		burn_timer -= delta
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			burn_tick_timer = 0.5
			health -= burn_damage_per_tick
			_spawn_hit_effect()
			print("Burn tick: ", name, " took ", burn_damage_per_tick, " damage, health=", health)
			if health <= 0:
				_enter_state(State.DEATH)
				_end_burn()
				move_and_slide()
				return
		if burn_timer <= 0.0:
			_end_burn()

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)

	# Reveal when player approaches
	if not _revealed and _player and is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist < DETECTION_RANGE:
			_revealed = true
			print("Ghoul revealed — player in range")
			print("Ghoul eyes activating")
			var reveal_tween := create_tween().set_parallel(true)
			if _eye_light:
				reveal_tween.tween_property(_eye_light, "energy", 1.2, 0.4)
			if _rim_material:
				reveal_tween.tween_method(func(val: float) -> void:
					if _rim_material:
						_rim_material.set_shader_parameter("rim_color", Color(0.28, 0.07, 0.42, val))
				, 0.0, 0.4, 0.4)

	# Tick cooldowns
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	_shield_blocked_timer = max(_shield_blocked_timer - delta, 0.0)

	# Stun overrides everything — no movement or attacks
	if is_stunned:
		stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		if stun_timer <= 0.0:
			is_stunned = false
			_enter_state(State.IDLE)
		move_and_slide()
		return

	# Root — can still attack but cannot move horizontally
	if is_rooted:
		root_timer -= delta
		if root_timer <= 0.0:
			_end_root()

	match state:
		State.IDLE:
			velocity.x = 0.0
			_check_detection()
		State.WAKE:
			velocity.x = 0.0
		State.CHASE:
			_chase_player(delta)
		State.PATROL:
			_patrol(delta)
		State.ATTACK:
			velocity.x = 0.0
			_check_attack_damage()
		State.HIT:
			hit_stun_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if hit_stun_timer <= 0.0:
				if health <= 0:
					_enter_state(State.DEATH)
				else:
					_enter_state(State.CHASE)
		State.DEATH:
			velocity.x = 0.0
		State.RECOVER:
			recover_timer -= delta
			# Move away from player
			if _player:
				var away_dir: float = sign(global_position.x - _player.global_position.x)
				if away_dir == 0.0:
					away_dir = -facing
				# Ledge check before backing up
				if is_on_floor() and _check_ledge_ahead(away_dir):
					velocity.x = 0.0
				else:
					velocity.x = away_dir * RECOVER_SPEED
				animated_sprite.flip_h = away_dir > 0  # face player while backing up
			if recover_timer <= 0.0:
				_enter_state(State.REPOSITION)
		State.REPOSITION:
			reposition_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
			if reposition_timer <= 0.0:
				_enter_state(State.CHASE)

	# Root freezes horizontal movement after AI runs
	if is_rooted:
		velocity.x = 0.0

	# Soft body separation — prevent overlapping player
	if _player and state != State.DEATH:
		var dx: float = global_position.x - _player.global_position.x
		var abs_dx: float = absf(dx)
		if abs_dx < SOFT_SEPARATION_DIST and abs_dx > 0.1:
			var push_dir: float = sign(dx)
			var overlap: float = SOFT_SEPARATION_DIST - abs_dx
			var push: float = push_dir * overlap * 3.0  # proportional push
			velocity.x += clampf(push, -SOFT_SEPARATION_FORCE, SOFT_SEPARATION_FORCE)

	# Apply knockback if any
	if knockback_velocity.length() > 10.0:
		velocity.x = knockback_velocity.x
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)

	move_and_slide()


func _check_detection() -> void:
	if _player == null:
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist < DETECTION_RANGE:
		_face_player()
		_enter_state(State.WAKE)


func _check_ledge_ahead(dir: float) -> bool:
	# Returns true if there's a ledge (no floor) in the given direction
	var check := floor_check_right if dir > 0 else floor_check_left
	if check and not check.is_colliding():
		return true
	return false


func _chase_player(_delta: float) -> void:
	if _player == null:
		_enter_state(State.IDLE)
		return

	_face_player()
	var dist := global_position.distance_to(_player.global_position)

	# Can attack if in range AND cooldown is done
	if dist < ATTACK_RANGE and attack_cooldown_timer <= 0.0:
		_enter_state(State.ATTACK)
		return

	if dist > DETECTION_RANGE * 1.5:
		_enter_state(State.PATROL)
		return

	# Ledge detection — don't chase off edges
	if is_on_floor() and _check_ledge_ahead(facing):
		velocity.x = 0.0
		print("Ghoul ledge detected — stopping")
		return

	velocity.x = facing * SPEED


func _patrol(delta: float) -> void:
	# Check if player is nearby — switch to chase
	if _player and is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist < DETECTION_RANGE:
			_enter_state(State.CHASE)
			return

	# Edge pause
	if _patrol_pause_timer > 0.0:
		_patrol_pause_timer -= delta
		velocity.x = 0.0
		return

	# Ledge detection — reverse at edges
	if is_on_floor() and _check_ledge_ahead(_patrol_dir):
		_patrol_dir = -_patrol_dir
		animated_sprite.flip_h = _patrol_dir < 0
		attack_area.scale.x = _patrol_dir
		_patrol_pause_timer = PATROL_EDGE_PAUSE
		velocity.x = 0.0
		print("Ghoul patrolling — reversed at edge")
		return

	velocity.x = _patrol_dir * PATROL_SPEED
	animated_sprite.flip_h = _patrol_dir < 0


func _face_player() -> void:
	if _player == null:
		return
	facing = sign(_player.global_position.x - global_position.x)
	if facing == 0.0:
		facing = -1.0
	# Sprite default faces RIGHT: flip_h=false means right, flip_h=true means left
	animated_sprite.flip_h = facing < 0
	# Flip attack area to match facing direction
	attack_area.scale.x = facing


func _check_attack_damage() -> void:
	if _has_dealt_damage:
		return
	# Deal damage mid-attack (frame 3-5 of 7)
	var frame := animated_sprite.frame
	if frame >= 3 and frame <= 5:
		for body in attack_area.get_overlapping_bodies():
			if body == _player:
				_has_dealt_damage = true
				if _player.has_method("take_damage"):
					_player.take_damage(global_position)


func _enter_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
			attack_count = 0
		State.PATROL:
			animated_sprite.play("walk")
		State.WAKE:
			animated_sprite.play("wake")
		State.CHASE:
			animated_sprite.play("walk")
		State.ATTACK:
			_face_player()
			_has_dealt_damage = false
			animated_sprite.play("attack")
			_attack_telegraph_flare()
		State.HIT:
			hit_stun_timer = HIT_STUN_TIME
			animated_sprite.play("hit")
		State.DEATH:
			animated_sprite.play("death")
			set_collision_layer_value(1, false)
			set_collision_layer_value(2, false)
			hitbox.set_deferred("monitoring", false)
			attack_area.set_deferred("monitoring", false)
		State.RECOVER:
			recover_timer = RECOVER_TIME
			animated_sprite.play("walk")
		State.REPOSITION:
			reposition_timer = 0.5
			animated_sprite.play("idle")


func _on_animation_finished() -> void:
	match state:
		State.WAKE:
			_enter_state(State.CHASE)
		State.ATTACK:
			_attack_telegraph_dim()
			attack_count += 1
			attack_cooldown_timer = ATTACK_COOLDOWN
			if attack_count >= MAX_CONSECUTIVE_ATTACKS:
				attack_count = 0
				_enter_state(State.RECOVER)
			else:
				# Go back to chase (cooldown prevents immediate re-attack)
				_enter_state(State.CHASE)
		State.DEATH:
			# Don't queue_free — hide and disable so we can revive on player death
			is_dead = true
			visible = false
			set_collision_layer_value(2, false)
			velocity = Vector2.ZERO


func _spawn_hit_effect() -> void:
	var HIT_FRAME_W := 82
	var HIT_FRAME_H := 65
	var HIT_FRAMES := 9
	var hit_tex := load("res://assets/effects/combat/hit/hit 4.png") as Texture2D

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("hit_spark")
	sf.set_animation_speed("hit_spark", 14.0)
	sf.set_animation_loop("hit_spark", false)
	for i in range(HIT_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = hit_tex
		atlas.region = Rect2(i * HIT_FRAME_W, 0, HIT_FRAME_W, HIT_FRAME_H)
		sf.add_frame("hit_spark", atlas)

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.z_index = 10
	sprite.scale = Vector2(0.3, 0.3)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = global_position + Vector2(0, -12)
	sprite.animation_finished.connect(sprite.queue_free)
	get_parent().add_child(sprite)
	sprite.play("hit_spark")
	print("Hit spark: ", HIT_FRAMES, " frames of ", HIT_FRAME_W, "x", HIT_FRAME_H, " @ 14 FPS, scale=0.3")


func take_damage_with_knockback(amount: int, knockback: Vector2) -> void:
	if state == State.DEATH:
		return
	_spawn_hit_effect()
	var actual_damage: int = int(amount * _petrify_damage_multiplier)
	health -= actual_damage
	if is_petrified:
		print("Ghoul petrified 2x damage: ", amount, " -> ", actual_damage)
	knockback_velocity = knockback
	print("Ghoul knockback applied: ", knockback, " health=", health)
	if health <= 0:
		_enter_state(State.DEATH)
	elif state != State.ATTACK:
		velocity.x = knockback.x
		velocity.y = -80.0
		attack_count = 0
		attack_cooldown_timer = 0.0
		_enter_state(State.HIT)


func take_damage(from_position: Vector2) -> void:
	if state == State.DEATH:
		return
	_spawn_hit_effect()
	var actual_damage: int = int(1 * _petrify_damage_multiplier)
	health -= actual_damage
	if is_petrified:
		print("Ghoul petrified 2x damage: 1 -> ", actual_damage)
	print("Ghoul hit! health=", health, " (during ", State.keys()[state], ")")
	# Knockback away from damage source
	var kb_dir: float = sign(global_position.x - from_position.x)
	if kb_dir == 0.0:
		kb_dir = -facing
	if state == State.ATTACK:
		# Enemy attacks CANNOT be interrupted — take damage but continue attack
		velocity.x = kb_dir * 40.0  # reduced knockback during attack
		if health <= 0:
			_enter_state(State.DEATH)
	else:
		velocity.x = kb_dir * 120.0
		velocity.y = -80.0
		attack_count = 0
		attack_cooldown_timer = 0.0
		_enter_state(State.HIT)


func take_knockback(from_position: Vector2) -> void:
	if state == State.DEATH:
		return
	var kb_dir: float = sign(global_position.x - from_position.x)
	if kb_dir == 0.0:
		kb_dir = -facing
	velocity.x = kb_dir * 150.0
	velocity.y = -60.0


func apply_repel(dir: float, force: float) -> void:
	if state == State.DEATH:
		return
	# Stop moving toward player, apply tiny push outward
	if sign(velocity.x) != sign(dir):
		velocity.x = 0.0
	velocity.x = move_toward(velocity.x, dir * force, force)


func apply_stun(duration: float) -> void:
	if state == State.DEATH:
		return
	is_stunned = true
	stun_timer = duration
	attack_count = 0
	attack_cooldown_timer = 0.0
	animated_sprite.play("hit")
	print("Ghoul STUNNED for ", duration, "s")


func apply_petrify(duration: float) -> void:
	if state == State.DEATH:
		return
	is_petrified = true
	petrify_timer = duration
	_petrify_damage_multiplier = 2.0
	velocity = Vector2.ZERO

	# Freeze animation on current frame
	animated_sprite.pause()
	print("Ghoul PETRIFIED for ", duration, "s — frame frozen, 2x damage")

	# Save original material and apply stone shader
	_petrify_original_material = animated_sprite.material
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec3 stone_color : source_color = vec3(0.196, 0.184, 0.157);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gray = vec3(lum);
	vec3 stoned = mix(gray, stone_color, 0.7);
	stoned *= 0.6;
	COLOR = vec4(stoned, tex.a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("stone_color", Vector3(0.196, 0.184, 0.157))
	animated_sprite.material = mat

	# Stone overlay
	var stone_tex := load("res://assets/effects/combat/summons/Petrify/Petrify Separeted Frames/Stone/Stone1.png") as Texture2D
	if stone_tex:
		_petrify_overlay = Sprite2D.new()
		_petrify_overlay.name = "StoneOverlay"
		_petrify_overlay.texture = stone_tex
		_petrify_overlay.modulate = Color(1, 1, 1, 0.5)
		_petrify_overlay.z_index = 1
		_petrify_overlay.position = Vector2(0, -16)
		_petrify_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_petrify_overlay)
		print("Ghoul: stone overlay applied")


func _end_petrify() -> void:
	is_petrified = false
	_petrify_damage_multiplier = 1.0
	print("Ghoul petrify ENDED — restoring normal state")

	# Remove stone shader
	animated_sprite.material = _petrify_original_material
	_petrify_original_material = null

	# Remove stone overlay
	if _petrify_overlay:
		_petrify_overlay.queue_free()
		_petrify_overlay = null

	# Play stone break animation
	_play_stone_break()

	# Resume AI
	animated_sprite.play()
	_enter_state(State.IDLE)


func _play_stone_break() -> void:
	var base_path := "res://assets/effects/combat/summons/Petrify/Petrify Separeted Frames/Stone/"
	var sf := SpriteFrames.new()
	sf.add_animation("stone_break")
	sf.set_animation_speed("stone_break", 12.0)
	sf.set_animation_loop("stone_break", false)

	var loaded := 0
	for i in range(1, 6):
		var tex := load(base_path + "Stone Break" + str(i) + ".png") as Texture2D
		if tex:
			sf.add_frame("stone_break", tex)
			loaded += 1

	if loaded == 0:
		print("Ghoul: no Stone Break frames loaded!")
		return

	var break_sprite := AnimatedSprite2D.new()
	break_sprite.sprite_frames = sf
	break_sprite.z_index = 10
	break_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	break_sprite.position = Vector2(0, -16)
	break_sprite.animation_finished.connect(break_sprite.queue_free)
	add_child(break_sprite)
	break_sprite.play("stone_break")
	print("Ghoul: playing Stone Break (", loaded, " frames)")


func apply_burn(duration: float, damage_per_tick: int) -> void:
	if state == State.DEATH:
		return
	# Refresh timer but don't stack damage
	is_burning = true
	burn_timer = duration
	burn_damage_per_tick = damage_per_tick
	if burn_tick_timer <= 0.0:
		burn_tick_timer = 0.5
	print("Ghoul BURNING for ", duration, "s, ", damage_per_tick, " damage per tick")

	# Start flicker tween if not already active
	if _burn_tween and _burn_tween.is_valid():
		return
	_burn_tween = create_tween().set_loops()
	_burn_tween.tween_property(animated_sprite, "modulate", Color(1.0, 0.5, 0.3, 1.0), 0.15)
	_burn_tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func _end_burn() -> void:
	is_burning = false
	burn_timer = 0.0
	burn_tick_timer = 0.0
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _burn_tween and _burn_tween.is_valid():
		_burn_tween.kill()
		_burn_tween = null
	print("Burn expired on ", name)


func apply_root(duration: float) -> void:
	if state == State.DEATH:
		return
	is_rooted = true
	root_timer = duration
	velocity.x = 0.0
	animated_sprite.modulate = Color(0.6, 0.5, 0.7, 1.0)
	print("Ghoul ROOTED for ", duration, "s")


func _end_root() -> void:
	is_rooted = false
	root_timer = 0.0
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	print("Root expired on ", name)


func _create_rim_light() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(0.28, 0.07, 0.42, 0.4);
uniform float rim_width : hint_range(0.0, 5.0) = 0.8;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Recolor red pixels to purple (eyes and blood effects)
	// Red pixels: r > 0.3, r > g * 2.0, r > b * 2.0
	float is_red = step(0.3, tex_color.r) * step(tex_color.g * 2.0, tex_color.r) * step(tex_color.b * 2.0, tex_color.r) * tex_color.a;
	vec3 purpled = vec3(tex_color.r * 0.5, tex_color.g * 0.3, tex_color.r * 0.8 + 0.1);
	tex_color.rgb = mix(tex_color.rgb, purpled, is_red);

	// Rim light edge detection
	vec2 size = TEXTURE_PIXEL_SIZE * rim_width;
	float neighbor = 0.0;

	neighbor += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
	neighbor += texture(TEXTURE, UV + vec2(size.x, 0)).a;
	neighbor += texture(TEXTURE, UV + vec2(0, -size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(0, size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(size.x, size.y)).a;

	neighbor = min(neighbor, 1.0);

	float rim_mask = neighbor * (1.0 - tex_color.a);
	vec4 rim = rim_color * rim_mask;
	COLOR = mix(rim, tex_color, tex_color.a);
}
"""
	_rim_material = ShaderMaterial.new()
	_rim_material.shader = shader
	_rim_material.set_shader_parameter("rim_color", Color(0.28, 0.07, 0.42, 0.0))
	_rim_material.set_shader_parameter("rim_width", 0.8)
	animated_sprite.material = _rim_material
	print("Ghoul rim light shader applied")


func _create_eye_light() -> void:
	_eye_light = PointLight2D.new()
	_eye_light.color = Color(0.5, 0.1, 0.6)
	_eye_light.energy = 0.0
	_eye_light.texture_scale = 0.8
	_eye_light.position = Vector2(0, -10)

	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var dist := Vector2(x, y).distance_to(center) / 32.0
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	_eye_light.texture = ImageTexture.create_from_image(img)
	add_child(_eye_light)
	print("Ghoul eye light created")


func _attack_telegraph_flare() -> void:
	if _telegraph_tween and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	_telegraph_tween = create_tween().set_parallel(true)
	if _eye_light:
		_telegraph_tween.tween_property(_eye_light, "energy", 3.0, 0.2)
	if _rim_material:
		_telegraph_tween.tween_method(func(val: float) -> void:
			if _rim_material:
				_rim_material.set_shader_parameter("rim_color", Color(0.28, 0.07, 0.42, val))
		, 0.4, 1.0, 0.2)
	print("Ghoul attack telegraph — eyes flare")


func _attack_telegraph_dim() -> void:
	if _telegraph_tween and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	_telegraph_tween = create_tween().set_parallel(true)
	if _eye_light:
		_telegraph_tween.tween_property(_eye_light, "energy", 1.2, 0.3)
	if _rim_material:
		_telegraph_tween.tween_method(func(val: float) -> void:
			if _rim_material:
				_rim_material.set_shader_parameter("rim_color", Color(0.28, 0.07, 0.42, val))
		, 1.0, 0.4, 0.3)
	print("Ghoul attack telegraph — eyes dim")


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body == _player and state == State.ATTACK:
		if _player.has_method("take_damage"):
			_player.take_damage(global_position)


func reset_to_spawn() -> void:
	state = State.IDLE
	health = 3
	velocity = Vector2.ZERO
	visible = true
	is_dead = false
	is_stunned = false
	is_petrified = false
	is_burning = false
	is_rooted = false
	_revealed = false
	attack_count = 0
	attack_cooldown_timer = 0.0
	knockback_velocity = Vector2.ZERO
	_patrol_pause_timer = 0.0
	# Re-enable collision
	set_collision_layer_value(2, true)
	hitbox.set_deferred("monitoring", true)
	attack_area.set_deferred("monitoring", true)
	# Reset visuals
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	animated_sprite.play("idle")
	# Reset reveal state — start hidden
	if _eye_light:
		_eye_light.energy = 0.0
	if _rim_material:
		_rim_material.set_shader_parameter("rim_color", Color(0.28, 0.07, 0.42, 0.0))
	print("Ghoul reset to spawn at: ", global_position)
