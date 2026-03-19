extends AnimatableBody2D

var start_pos: Vector2
var end_pos: Vector2
var speed: float = 40.0
var pause_time: float = 0.8

var _moving_to_end: bool = true
var _pause_timer: float = 0.0
var _progress: float = 0.0


func setup(p_start: Vector2, p_end: Vector2, p_width: float, p_height: float, p_speed: float, p_pause: float) -> void:
	start_pos = p_start
	end_pos = p_end
	speed = p_speed
	pause_time = p_pause

	global_position = start_pos + Vector2(p_width / 2.0, p_height / 2.0)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(p_width, p_height)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var rect := ColorRect.new()
	rect.position = Vector2(-p_width / 2.0, -p_height / 2.0)
	rect.size = Vector2(p_width, p_height)
	rect.color = Color(0.278, 0.329, 0.384)
	add_child(rect)

	_progress = 0.0


func _physics_process(delta: float) -> void:
	if _pause_timer > 0.0:
		_pause_timer -= delta
		return

	var total_dist := start_pos.distance_to(end_pos)
	if total_dist < 0.1:
		return

	var step := speed * delta / total_dist

	if _moving_to_end:
		_progress += step
		if _progress >= 1.0:
			_progress = 1.0
			_moving_to_end = false
			_pause_timer = pause_time
	else:
		_progress -= step
		if _progress <= 0.0:
			_progress = 0.0
			_moving_to_end = true
			_pause_timer = pause_time

	var half_size := Vector2.ZERO
	var col_child := get_child(0) as CollisionShape2D
	if col_child:
		var shape := col_child.shape as RectangleShape2D
		if shape:
			half_size = shape.size / 2.0

	var target := start_pos.lerp(end_pos, _progress) + half_size
	global_position = target
