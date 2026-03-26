class_name TornadoSummon
extends BaseSummon

enum Phase { START, LOOP, ENDING }

var phase: Phase = Phase.START
var loop_timer: float = 0.0
var loop_duration: float = 3.0
var damage_tick_timer: float = 0.0
var damage_tick_interval: float = 0.5
var pull_radius: float = 120.0
var pull_strength: float = 150.0
var damage_radius: float = 40.0
var spin_radius: float = 50.0
var spin_timer: float = 0.0
var spin_interval: float = 0.1
var tick_hit_enemies: Array = []
var spinning_enemies: Array = []


func _init():
	summon_name = "Tornado"
	texture_path = ""
	frame_size = Vector2(32, 32)
	animation_speed = 12.0
	damage = 1
	knockback_force = 0.0
	spawn_offset = Vector2(80, -15)
	hitbox_start_frame = 0
	hitbox_end_frame = 0
	match_environment_color = false
	magical_aura_enabled = true
	aura_color = Color(0.4, 0.8, 0.5, 1.0)
	ghost_interval = 0.06


func _ready():
	_setup_animation()

	animated_sprite.flip_h = (direction == -1)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.frame = 0
	animated_sprite.play("start")
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Disable hitbox — tornado uses custom pull/damage, not standard hitbox
	if hitbox:
		hitbox.monitoring = false

	if magical_aura_enabled:
		_apply_magical_aura()

	print("Tornado summoned, direction: ", direction)
	print("Tornado START phase")


func _setup_animation():
	var base_path = "res://assets/effects/combat/summons/Tornado/Separated Frames Tornado/"

	var sprite_frames = SpriteFrames.new()

	# Start animation — plays once
	sprite_frames.add_animation("start")
	sprite_frames.set_animation_speed("start", animation_speed)
	sprite_frames.set_animation_loop("start", false)
	var start_count = 0
	for i in range(1, 6):
		var tex = load(base_path + "TornadoStart" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("start", tex)
			start_count += 1

	# Loop animation — loops
	sprite_frames.add_animation("loop")
	sprite_frames.set_animation_speed("loop", animation_speed)
	sprite_frames.set_animation_loop("loop", true)
	var loop_count = 0
	for i in range(1, 7):
		var tex = load(base_path + "TornadoRepeatable" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("loop", tex)
			loop_count += 1

	# Ending animation — plays once
	sprite_frames.add_animation("ending")
	sprite_frames.set_animation_speed("ending", animation_speed)
	sprite_frames.set_animation_loop("ending", false)
	var ending_count = 0
	for i in range(1, 7):
		var tex = load(base_path + "TornadoEnding" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("ending", tex)
			ending_count += 1

	animated_sprite.sprite_frames = sprite_frames
	frame_count = start_count + loop_count + ending_count

	scale = Vector2(2.5, 2.5)

	print("Tornado frames: start=", start_count, " loop=", loop_count, " ending=", ending_count)


func _process(delta: float):
	# Keep outline in sync with main sprite
	var outline = get_node_or_null("AuraOutline") as AnimatedSprite2D
	if outline and animated_sprite:
		# Sync outline to same animation and frame
		if outline.animation != animated_sprite.animation:
			outline.play(animated_sprite.animation)
		outline.frame = animated_sprite.frame

	# Ghost trails
	if magical_aura_enabled and animated_sprite:
		_ghost_timer += delta
		if _ghost_timer >= ghost_interval:
			_ghost_timer = 0.0
			_spawn_summon_ghost()

	# Only pull/damage during loop phase
	if phase != Phase.LOOP:
		return

	loop_timer += delta
	if loop_timer >= loop_duration:
		_start_ending()
		return

	# Damage tick timer
	damage_tick_timer += delta
	var can_damage = false
	if damage_tick_timer >= damage_tick_interval:
		damage_tick_timer = 0.0
		tick_hit_enemies.clear()
		can_damage = true

	# Spin timer
	spin_timer += delta
	var do_spin = false
	if spin_timer >= spin_interval:
		spin_timer = 0.0
		do_spin = true

	# Process all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is CharacterBody2D:
			continue

		var dist = abs(enemy.global_position.x - global_position.x)

		# Pull mechanic
		if dist < pull_radius and dist > 5.0:
			var dir_to_center = sign(global_position.x - enemy.global_position.x)
			var strength_scale = 1.0 - (dist / pull_radius)
			enemy.velocity.x += dir_to_center * pull_strength * strength_scale * delta
			print("Pulling ", enemy.name, " toward center (dist=", int(dist), ")")

		# Damage tick
		if can_damage and dist < damage_radius and enemy not in tick_hit_enemies:
			tick_hit_enemies.append(enemy)
			if enemy.has_method("take_damage"):
				enemy.take_damage(global_position)
				print("Tornado damage tick on ", enemy.name)

		# Spin visual
		if do_spin and dist < spin_radius:
			if enemy.has_node("AnimatedSprite2D"):
				var sprite = enemy.get_node("AnimatedSprite2D")
				sprite.flip_h = not sprite.flip_h
			if enemy not in spinning_enemies:
				spinning_enemies.append(enemy)


func _start_ending():
	phase = Phase.ENDING
	animated_sprite.play("ending")
	print("Tornado ENDING phase")

	# Reset spin on all affected enemies
	_reset_spinning_enemies()


func _reset_spinning_enemies():
	var player = get_tree().get_first_node_in_group("player")
	for enemy in spinning_enemies:
		if is_instance_valid(enemy) and enemy.has_node("AnimatedSprite2D"):
			var sprite = enemy.get_node("AnimatedSprite2D")
			if player:
				sprite.flip_h = enemy.global_position.x > player.global_position.x
			else:
				sprite.flip_h = false
	spinning_enemies.clear()
	print("Tornado: reset enemy spin orientations")


func _on_animation_finished():
	match phase:
		Phase.START:
			phase = Phase.LOOP
			animated_sprite.play("loop")
			print("Tornado LOOPING phase (", loop_duration, "s)")
		Phase.ENDING:
			magical_aura_enabled = false
			var outline_node = get_node_or_null("AuraOutline")
			if outline_node:
				outline_node.queue_free()
			queue_free()
			print("Tornado finished — removed")
