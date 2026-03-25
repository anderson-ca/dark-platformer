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

	print(summon_name, " summoned, direction: ", direction)


func _process(_delta: float) -> void:
	if animated_sprite and hitbox:
		var current_frame: int = animated_sprite.frame
		if current_frame >= hitbox_start_frame and current_frame <= hitbox_end_frame:
			if not _hitbox_enabled:
				hitbox.monitoring = true
				_hitbox_enabled = true
				print(summon_name, " hitbox ACTIVE frame ", current_frame)
		else:
			if _hitbox_enabled:
				hitbox.monitoring = false
				_hitbox_enabled = false


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

		print(summon_name, " hit enemy: ", enemy.name)


func _apply_environment_color_match() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec3 target_color : source_color = vec3(0.196, 0.184, 0.157);
uniform float blend_amount : hint_range(0.0, 1.0) = 0.6;
uniform float darken_amount : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = vec3(lum) * 0.7 + tex_color.rgb * 0.3;
	vec3 tinted = mix(desat, target_color * (lum + 0.3), blend_amount);
	tinted *= (1.0 - darken_amount);
	COLOR = vec4(tinted, tex_color.a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("target_color", Vector3(environment_base_color.r, environment_base_color.g, environment_base_color.b))
	mat.set_shader_parameter("blend_amount", 0.65)
	mat.set_shader_parameter("darken_amount", 0.4)
	animated_sprite.material = mat
	print(summon_name, ": Applied environment color match -> ", environment_base_color)


func _on_animation_finished() -> void:
	queue_free()
