class_name BaseSummon
extends Node2D

# Override in child classes
var summon_name: String = "Base"
var texture_path: String = ""
var frame_count: int = 8
var frame_size: Vector2 = Vector2(48, 48)
var cols: int = 0  # 0 = single row, auto-calculated
var start_frame: int = 0  # Which frame to start from in the sheet
var animation_speed: float = 12.0

# Stats
var damage: int = 2
var knockback_force: float = 200.0

# Spawn offset from player
var spawn_offset: Vector2 = Vector2(50, 0)

# Hitbox active frames (override in children)
var hitbox_start_frame: int = 0
var hitbox_end_frame: int = 999
var _hitbox_enabled: bool = false

# Environment color matching
var match_environment_color: bool = false
var environment_base_color: Color = Color(0.196, 0.184, 0.157)  # #322F28

# Magical aura
var magical_aura_enabled: bool = false
var aura_color: Color = Color(0.7, 0.2, 1.0, 1.0)
var ghost_interval: float = 0.05
var _ghost_timer: float = 0.0

# Runtime
var direction: int = 1
var hit_enemies: Array = []

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	_setup_animation()

	animated_sprite.flip_h = (direction == -1)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.frame = 0
	animated_sprite.play("summon")
	animated_sprite.animation_finished.connect(_on_animation_finished)

	if hitbox:
		hitbox.monitoring = false
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	if match_environment_color:
		_apply_environment_color_match()

	if magical_aura_enabled:
		_apply_magical_aura()



func _process(delta: float) -> void:
	if animated_sprite and hitbox:
		var current_frame: int = animated_sprite.frame
		if current_frame >= hitbox_start_frame and current_frame <= hitbox_end_frame:
			if not _hitbox_enabled:
				hitbox.monitoring = true
				_hitbox_enabled = true
		else:
			if _hitbox_enabled:
				hitbox.monitoring = false
				_hitbox_enabled = false

	# Keep outline in sync with main sprite
	var outline := get_node_or_null("AuraOutline") as AnimatedSprite2D
	if outline and animated_sprite:
		outline.frame = animated_sprite.frame

	# Ghost trails
	if magical_aura_enabled and animated_sprite:
		if animated_sprite.frame < frame_count - 2:
			_ghost_timer += delta
			if _ghost_timer >= ghost_interval:
				_ghost_timer = 0.0
				_spawn_summon_ghost()


func _setup_animation() -> void:
	if texture_path.is_empty():
		return

	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_error("Could not load summon texture: " + texture_path)
		return

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("summon")
	sf.set_animation_speed("summon", animation_speed)
	sf.set_animation_loop("summon", false)

	# Support grid-based sprite sheets (multiple rows)
	var num_cols: int = cols if cols > 0 else frame_count
	for i in range(frame_count):
		var actual_frame: int = start_frame + i
		var col: int = actual_frame % num_cols
		var row: int = actual_frame / num_cols
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
		sf.add_frame("summon", atlas)

	animated_sprite.sprite_frames = sf


func _on_hitbox_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy and enemy.has_method("take_damage") and enemy not in hit_enemies:
		hit_enemies.append(enemy)

		var knockback_dir := Vector2(direction, -0.5).normalized()

		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(damage, knockback_dir * knockback_force)
		else:
			enemy.take_damage(global_position)



func _apply_environment_color_match() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/summon_env_color.gdshader")
	mat.set_shader_parameter("target_color", Vector3(environment_base_color.r, environment_base_color.g, environment_base_color.b))
	mat.set_shader_parameter("blend_amount", 0.65)
	mat.set_shader_parameter("darken_amount", 0.4)
	animated_sprite.material = mat


func _apply_magical_aura() -> void:
	_add_outline_sprite()


func _add_outline_sprite() -> void:
	var outline := AnimatedSprite2D.new()
	outline.name = "AuraOutline"
	outline.sprite_frames = animated_sprite.sprite_frames
	outline.flip_h = animated_sprite.flip_h
	outline.z_index = -1
	outline.centered = animated_sprite.centered
	outline.offset = animated_sprite.offset
	outline.position = animated_sprite.position
	outline.scale = animated_sprite.scale

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/summon_aura_outline.gdshader")
	mat.set_shader_parameter("outline_color", aura_color)
	mat.set_shader_parameter("outline_width", 0.8)
	outline.material = mat

	add_child(outline)
	outline.play("summon")

	# Pulse the outline
	var tween := create_tween().set_loops()
	tween.tween_method(func(val: float) -> void:
		if is_instance_valid(outline) and outline.material:
			outline.material.set_shader_parameter("pulse", val)
	, 0.5, 1.0, 0.3)
	tween.tween_method(func(val: float) -> void:
		if is_instance_valid(outline) and outline.material:
			outline.material.set_shader_parameter("pulse", val)
	, 1.0, 0.5, 0.3)


func _spawn_summon_ghost() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	# Don't spawn ghosts on the last few frames
	if animated_sprite.frame >= frame_count - 2:
		return

	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames = animated_sprite.sprite_frames
	ghost.animation = "summon"
	ghost.frame = animated_sprite.frame
	ghost.global_position = global_position
	ghost.scale = scale
	ghost.flip_h = animated_sprite.flip_h
	ghost.z_index = z_index - 1
	ghost.pause()
	ghost.modulate = Color(aura_color.r, aura_color.g, aura_color.b, 0.5)

	get_parent().add_child(ghost)

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


func _on_animation_finished() -> void:
	magical_aura_enabled = false
	var outline := get_node_or_null("AuraOutline")
	if outline:
		outline.queue_free()
	queue_free()
