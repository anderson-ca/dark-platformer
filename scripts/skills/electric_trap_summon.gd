class_name ElectricTrapSummon
extends BaseSummon

enum TrapPhase { INACTIVE, ACTIVE }

var trap_phase: TrapPhase = TrapPhase.INACTIVE
var lifetime_timer: float = 8.0
var trigger_range_x: float = 45.0
var trigger_range_y: float = 30.0
var _light: PointLight2D = null
var _triggered_enemy: Node2D = null
var _enemy_flicker_tween: Tween = null


func _init():
	summon_name = "Electric Trap"
	texture_path = ""
	frame_size = Vector2(48, 48)
	animation_speed = 6.0
	damage = 2
	knockback_force = 50.0
	spawn_offset = Vector2(90, 8)
	hitbox_start_frame = 0
	hitbox_end_frame = 0
	match_environment_color = false
	magical_aura_enabled = false


func _ready():
	_setup_animation()

	animated_sprite.flip_h = (direction == -1)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.frame = 0
	animated_sprite.play("inactive")
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Disable hitbox during inactive
	if hitbox:
		hitbox.monitoring = false
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	scale = Vector2(1.8, 1.8)

	_create_light()

	print("Electric Trap placed at ", global_position)


func _create_light():
	_light = PointLight2D.new()
	_light.name = "ElectricLight"
	_light.color = Color(0.5, 0.7, 1.0)
	_light.energy = 0.0
	_light.texture_scale = 3.0
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
	if trap_phase == TrapPhase.INACTIVE:
		# Lifetime countdown
		lifetime_timer -= delta
		if lifetime_timer <= 0.0:
			print("Electric Trap expired (no enemy)")
			queue_free()
			return

		# Check for nearby enemies
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy) or not enemy is CharacterBody2D:
				continue
			var dx = abs(enemy.global_position.x - global_position.x)
			var dy = abs(enemy.global_position.y - global_position.y)
			if dx < trigger_range_x and dy < trigger_range_y:
				_trigger(enemy)
				return


func _trigger(enemy: Node2D):
	trap_phase = TrapPhase.ACTIVE
	_triggered_enemy = enemy
	print("Electric Trap TRIGGERED by ", enemy.name)

	# Switch to active animation
	animated_sprite.play("active")

	# Enable hitbox
	if hitbox:
		hitbox.monitoring = true

	# Deal damage
	if enemy.has_method("take_damage_with_knockback"):
		var knockback_dir = Vector2(direction, -0.3).normalized()
		enemy.take_damage_with_knockback(damage, knockback_dir * knockback_force)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(global_position)

	# Stun
	if enemy.has_method("apply_stun"):
		enemy.apply_stun(2.0)
		print("Electric stun applied to ", enemy.name, " for 2s")

	# Electric flicker on enemy
	if enemy.has_node("AnimatedSprite2D"):
		_enemy_flicker_tween = enemy.create_tween().set_loops()
		_enemy_flicker_tween.tween_property(enemy.get_node("AnimatedSprite2D"), "modulate", Color(0.7, 0.9, 1.0, 1.0), 0.08)
		_enemy_flicker_tween.tween_property(enemy.get_node("AnimatedSprite2D"), "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
		# Stop flicker after 2 seconds
		get_tree().create_timer(2.0).timeout.connect(_stop_enemy_flicker)

	# Light flash
	if _light:
		var tween = create_tween()
		tween.tween_property(_light, "energy", 4.0, 0.02)
		tween.tween_property(_light, "energy", 0.0, 0.5)

	# Enable magical aura on trigger
	magical_aura_enabled = true
	aura_color = Color(0.5, 0.7, 1.0, 1.0)
	_apply_magical_aura()

	# Screen flash
	_screen_flash()


func _stop_enemy_flicker():
	if _enemy_flicker_tween and _enemy_flicker_tween.is_valid():
		_enemy_flicker_tween.kill()
		_enemy_flicker_tween = null
	if is_instance_valid(_triggered_enemy) and _triggered_enemy.has_node("AnimatedSprite2D"):
		_triggered_enemy.get_node("AnimatedSprite2D").modulate = Color(1.0, 1.0, 1.0, 1.0)


func _screen_flash():
	var canvas_mod: CanvasModulate = null
	for node in get_tree().root.get_children():
		canvas_mod = _find_canvas_modulate(node)
		if canvas_mod:
			break

	if canvas_mod:
		var original_color = canvas_mod.color
		var flash_color = Color(0.4, 0.45, 0.55, 1.0)
		var tween = create_tween()
		tween.tween_property(canvas_mod, "color", flash_color, 0.03)
		tween.tween_property(canvas_mod, "color", original_color, 0.1)


func _find_canvas_modulate(node: Node) -> CanvasModulate:
	if node is CanvasModulate:
		return node
	for child in node.get_children():
		var result = _find_canvas_modulate(child)
		if result:
			return result
	return null


func _setup_animation():
	var base_path = "res://assets/effects/combat/summons/Eletric Trap (48x48)/Eletric Trap Separeted Frames/"

	var sprite_frames = SpriteFrames.new()

	# Inactive — looping, slow pulse
	sprite_frames.add_animation("inactive")
	sprite_frames.set_animation_speed("inactive", 6.0)
	sprite_frames.set_animation_loop("inactive", true)
	var inactive_count = 0
	for i in range(1, 7):
		var tex = load(base_path + "Eletric Trap Inactive" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("inactive", tex)
			inactive_count += 1

	# Active — fast shock, no loop
	sprite_frames.add_animation("active")
	sprite_frames.set_animation_speed("active", 14.0)
	sprite_frames.set_animation_loop("active", false)
	var active_count = 0
	for i in range(1, 8):
		var tex = load(base_path + "Eletric Trap Active" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("active", tex)
			active_count += 1

	animated_sprite.sprite_frames = sprite_frames
	frame_count = inactive_count + active_count

	print("Electric Trap: Inactive=", inactive_count, " Active=", active_count)


func _on_animation_finished():
	if trap_phase == TrapPhase.ACTIVE:
		_stop_enemy_flicker()
		magical_aura_enabled = false
		var outline = get_node_or_null("AuraOutline")
		if outline:
			outline.queue_free()
		queue_free()
