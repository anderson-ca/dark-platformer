extends CharacterBody2D

enum State { IDLE, WAKE, CHASE, ATTACK, HIT, DEATH }

const SPEED := 60.0
const GRAVITY := 1400.0
const MAX_FALL_SPEED := 880.0
const DETECTION_RANGE := 300.0
const ATTACK_RANGE := 40.0
const HIT_STUN_TIME := 0.3
const FRAME_W := 62
const FRAME_H := 33

var state: State = State.IDLE
var health: int = 3
var facing: float = -1.0
var hit_stun_timer: float = 0.0
var _player: CharacterBody2D = null
var _has_dealt_damage: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
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

	print("Ghoul ready: health=", health, " player=", _player)


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

		print("  Ghoul ", anim_name, ": ", frame_count, " frames @ ", fps, " FPS")

	animated_sprite.sprite_frames = sf
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.play("idle")


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)

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

	if dist < ATTACK_RANGE:
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
			# Disable collisions on death
			set_collision_layer_value(1, false)
			set_collision_layer_value(2, false)
			hitbox.set_deferred("monitoring", false)
			attack_area.set_deferred("monitoring", false)


func _on_animation_finished() -> void:
	match state:
		State.WAKE:
			_enter_state(State.CHASE)
		State.ATTACK:
			# Check if player still in range
			if _player and global_position.distance_to(_player.global_position) < ATTACK_RANGE * 1.5:
				_enter_state(State.ATTACK)
			else:
				_enter_state(State.CHASE)
		State.DEATH:
			queue_free()


func take_damage(from_position: Vector2) -> void:
	if state == State.DEATH:
		return
	health -= 1
	# Knockback away from damage source
	var kb_dir: float = sign(global_position.x - from_position.x)
	if kb_dir == 0.0:
		kb_dir = -facing
	velocity.x = kb_dir * 120.0
	velocity.y = -80.0
	_enter_state(State.HIT)
	print("Ghoul hit! health=", health)


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body == _player and state == State.ATTACK:
		if _player.has_method("take_damage"):
			_player.take_damage(global_position)
