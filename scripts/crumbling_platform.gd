extends Node2D

var platform_w: float
var platform_h: float
var shake_duration: float = 0.5
var respawn_time: float = 3.0

var _shaking: bool = false
var _shake_timer: float = 0.0
var _collapsed: bool = false
var _respawn_timer: float = 0.0
var _origin_pos: Vector2
var _body: StaticBody2D


func setup(_x: float, _y: float, w: float, h: float, p_shake: float, p_respawn: float) -> void:
	platform_w = w
	platform_h = h
	shake_duration = p_shake
	respawn_time = p_respawn


func _ready() -> void:
	_build()


func _build() -> void:
	_body = StaticBody2D.new()
	_body.position = Vector2(platform_w / 2.0, platform_h / 2.0)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(platform_w, platform_h)
	var col := CollisionShape2D.new()
	col.shape = shape
	_body.add_child(col)

	var color_rect := ColorRect.new()
	color_rect.position = Vector2(-platform_w / 2.0, -platform_h / 2.0)
	color_rect.size = Vector2(platform_w, platform_h)
	color_rect.color = Color(0.278, 0.329, 0.384)
	_body.add_child(color_rect)

	add_child(_body)

	# Area2D to detect player stepping on top
	var area := Area2D.new()
	area.position = Vector2(platform_w / 2.0, -2.0)
	area.collision_layer = 0
	area.collision_mask = 1

	var area_shape := RectangleShape2D.new()
	area_shape.size = Vector2(platform_w, 8.0)
	var area_col := CollisionShape2D.new()
	area_col.shape = area_shape
	area.add_child(area_col)

	area.body_entered.connect(_on_body_entered)
	add_child(area)

	_origin_pos = _body.position


func _on_body_entered(b: Node2D) -> void:
	if b is CharacterBody2D and not _shaking and not _collapsed:
		_shaking = true
		_shake_timer = shake_duration


func _process(delta: float) -> void:
	if _shaking:
		_shake_timer -= delta
		_body.position = _origin_pos + Vector2(randf_range(-2, 2), randf_range(-1, 1))
		if _shake_timer <= 0.0:
			_shaking = false
			_collapsed = true
			_respawn_timer = respawn_time
			_body.visible = false
			for child in _body.get_children():
				if child is CollisionShape2D:
					child.set_deferred("disabled", true)

	if _collapsed:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_collapsed = false
			_body.visible = true
			_body.position = _origin_pos
			for child in _body.get_children():
				if child is CollisionShape2D:
					child.set_deferred("disabled", false)
