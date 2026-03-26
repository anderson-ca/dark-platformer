class_name ThunderBurstSummon
extends BaseSummon

var _active_triggered: bool = false
var _start_frame_count: int = 4
var _light: PointLight2D = null


func _init():
	summon_name = "Thunder Burst"
	texture_path = ""
	frame_size = Vector2(48, 48)
	animation_speed = 16.0
	damage = 4
	knockback_force = 280.0
	spawn_offset = Vector2(70, -15)

	# Hitbox only during Active frames (after 4 Start frames)
	hitbox_start_frame = 4
	hitbox_end_frame = 10

	match_environment_color = false

	magical_aura_enabled = true
	aura_color = Color(1.0, 0.95, 0.4, 1.0)
	ghost_interval = 0.04


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	scale = Vector2(2.0, 2.0)
	_create_light()
	print("Thunder Burst CHARGING")


func _create_light():
	_light = PointLight2D.new()
	_light.name = "ThunderLight"
	_light.color = Color(1.0, 0.95, 0.6)
	_light.energy = 0.0
	_light.texture_scale = 5.0
	_light.blend_mode = Light2D.BLEND_MODE_ADD

	# Create radial gradient texture
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
	# Call base _process for hitbox management, outline sync, ghost trails
	super._process(delta)

	# Detect transition from Start to Active phase
	if not _active_triggered and animated_sprite and animated_sprite.frame >= _start_frame_count:
		_active_triggered = true
		_trigger_active_effects()


func _trigger_active_effects():
	print("Thunder Burst ACTIVE — flash triggered")
	_flash_light()
	_screen_flash()
	_camera_shake()


func _flash_light():
	if not _light:
		return
	var tween = create_tween()
	tween.tween_property(_light, "energy", 6.0, 0.05)
	tween.tween_property(_light, "energy", 0.0, 0.3)


func _screen_flash():
	# Flash CanvasModulate
	var canvas_mod: CanvasModulate = null
	for node in get_tree().root.get_children():
		canvas_mod = _find_canvas_modulate(node)
		if canvas_mod:
			break

	if canvas_mod:
		var original_color = canvas_mod.color
		var flash_color = Color(0.9, 0.85, 0.7, 1.0)
		var tween = create_tween()
		tween.tween_property(canvas_mod, "color", flash_color, 0.03)
		tween.tween_property(canvas_mod, "color", original_color, 0.15)

	# Flash ParallaxBackground
	var parallax = get_tree().root.find_child("ParallaxBackground", true, false)
	if parallax:
		var orig_mod = parallax.modulate
		var tween = create_tween()
		tween.tween_property(parallax, "modulate", Color(1.5, 1.4, 1.2, 1.0), 0.03)
		tween.tween_property(parallax, "modulate", orig_mod, 0.15)


func _find_canvas_modulate(node: Node) -> CanvasModulate:
	if node is CanvasModulate:
		return node
	for child in node.get_children():
		var result = _find_canvas_modulate(child)
		if result:
			return result
	return null


func _camera_shake():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var camera = player.get_node_or_null("Camera2D") as Camera2D
	if not camera:
		return

	var original_offset = camera.offset
	var shake_tween = create_tween()
	# Rapid random offsets
	for i in range(6):
		var rand_offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		shake_tween.tween_property(camera, "offset", original_offset + rand_offset, 0.025)
	shake_tween.tween_property(camera, "offset", original_offset, 0.025)


func _on_hitbox_area_entered(area: Area2D):
	var enemy = area.get_parent()
	if enemy and enemy.has_method("take_damage") and enemy not in hit_enemies:
		hit_enemies.append(enemy)

		var knockback_dir = Vector2(direction, -0.5).normalized()

		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(damage, knockback_dir * knockback_force)
		else:
			enemy.take_damage(global_position)

		print("Thunder Burst hit enemy: ", enemy.name)

		# Hitstop — freeze frame on impact
		_apply_hitstop()


func _apply_hitstop():
	get_tree().paused = true
	print("Thunder hitstop applied")
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func():
		get_tree().paused = false
	)


func _setup_animation():
	var base_path = "res://assets/effects/combat/summons/electrict burst/Thunder Burst Separeted Frames/"

	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("summon")
	sprite_frames.set_animation_speed("summon", animation_speed)
	sprite_frames.set_animation_loop("summon", false)

	# Start phase
	var start_count = 0
	for i in range(1, 5):
		var tex = load(base_path + "Start/Thunder BurstStart" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("summon", tex)
			start_count += 1
		else:
			push_error("Could not load: Thunder BurstStart" + str(i) + ".png")

	# Active phase
	var active_count = 0
	for i in range(1, 8):
		var tex = load(base_path + "Active/Thunder BurstActive" + str(i) + ".png")
		if tex:
			sprite_frames.add_frame("summon", tex)
			active_count += 1
		else:
			push_error("Could not load: Thunder BurstActive" + str(i) + ".png")

	animated_sprite.sprite_frames = sprite_frames
	frame_count = start_count + active_count
	_start_frame_count = start_count

	print("Thunder Burst: Start=", start_count, " Active=", active_count, " Total=", frame_count)
