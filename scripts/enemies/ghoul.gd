extends CharacterBody2D

enum State { IDLE, WAKE, CHASE, ATTACK, HIT, DEATH, RECOVER, REPOSITION }

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
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)

	# Tick cooldowns
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	_shield_blocked_timer = max(_shield_blocked_timer - delta, 0.0)

	match state:
		State.IDLE:
			velocity.x = 0.0
			_check_detection()
		State.WAKE:
			velocity.x = 0.0
		State.CHASE:
			_chase_player(delta)
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
				velocity.x = away_dir * RECOVER_SPEED
				animated_sprite.flip_h = away_dir > 0  # face player while backing up
			if recover_timer <= 0.0:
				_enter_state(State.REPOSITION)
		State.REPOSITION:
			reposition_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
			if reposition_timer <= 0.0:
				_enter_state(State.CHASE)

	# Soft body separation — prevent overlapping player
	if _player and state != State.DEATH:
		var dx: float = global_position.x - _player.global_position.x
		var abs_dx: float = absf(dx)
		if abs_dx < SOFT_SEPARATION_DIST and abs_dx > 0.1:
			var push_dir: float = sign(dx)
			var overlap: float = SOFT_SEPARATION_DIST - abs_dx
			var push: float = push_dir * overlap * 3.0  # proportional push
			velocity.x += clampf(push, -SOFT_SEPARATION_FORCE, SOFT_SEPARATION_FORCE)

	move_and_slide()


func _check_detection() -> void:
	if _player == null:
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist < DETECTION_RANGE:
		_face_player()
		_enter_state(State.WAKE)


func _chase_player(_delta: float) -> void:
	if _player == null:
		_enter_state(State.IDLE)
		return

	_face_player()
	var dist := global_position.distance_to(_player.global_position)

	# If player is shielding and we're close, just stop — don't retreat
	if _player.is_shielding and dist < ATTACK_RANGE * 2.0:
		velocity.x = 0.0
		return

	# Can attack if in range AND cooldown is done
	if dist < ATTACK_RANGE and attack_cooldown_timer <= 0.0:
		_enter_state(State.ATTACK)
		return

	if dist > DETECTION_RANGE * 1.5:
		_enter_state(State.IDLE)
		return

	velocity.x = facing * SPEED


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
		State.WAKE:
			animated_sprite.play("wake")
		State.CHASE:
			animated_sprite.play("walk")
		State.ATTACK:
			_face_player()
			_has_dealt_damage = false
			animated_sprite.play("attack")
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
			attack_count += 1
			attack_cooldown_timer = ATTACK_COOLDOWN
			if attack_count >= MAX_CONSECUTIVE_ATTACKS:
				attack_count = 0
				_enter_state(State.RECOVER)
			else:
				# Go back to chase (cooldown prevents immediate re-attack)
				_enter_state(State.CHASE)
		State.DEATH:
			queue_free()


func take_damage(from_position: Vector2) -> void:
	if state == State.DEATH:
		return
	health -= 1
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


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body == _player and state == State.ATTACK:
		if _player.has_method("take_damage"):
			_player.take_damage(global_position)
