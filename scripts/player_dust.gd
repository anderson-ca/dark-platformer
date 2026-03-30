class_name PlayerDust

var _dust_run: AnimatedSprite2D
var _dust_land: AnimatedSprite2D
var _dust_wall: AnimatedSprite2D
var _dust_dash: AnimatedSprite2D
var _was_dashing: bool = false


func setup(player: Node2D) -> void:
	var E := "res://assets/effects/movement/"
	var feet_y := 9.0  # collision bottom: center(-1) + half-height(10)
	var DUST_FRAME := 128

	# Helper: build SpriteFrames from a horizontal strip of 128x128 frames
	var make_dust_frames := func(path: String, anim_name: String, frame_count: int, fps: float, loop: bool) -> SpriteFrames:
		var sf := SpriteFrames.new()
		if sf.has_animation("default"):
			sf.remove_animation("default")
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
		var tex := load(path) as Texture2D
		for i in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * DUST_FRAME, 0, DUST_FRAME, DUST_FRAME)
			sf.add_frame(anim_name, atlas)
		return sf

	# Helper: create a dust AnimatedSprite2D
	var make_dust_sprite := func(node_name: String, sf: SpriteFrames, pos: Vector2, sc: Vector2) -> AnimatedSprite2D:
		var sprite := AnimatedSprite2D.new()
		sprite.name = node_name
		sprite.sprite_frames = sf
		sprite.centered = true
		sprite.position = pos
		sprite.z_index = -1
		sprite.scale = sc
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.visible = false
		player.add_child(sprite)
		return sprite

	# 1. Run dust — jump_land_dust.png at 60% scale, looping, 10 fps
	var run_sf: SpriteFrames = make_dust_frames.call(E + "jump_land_dust.png", "run", 5, 10.0, true)
	_dust_run = make_dust_sprite.call("DustRun", run_sf, Vector2(0, feet_y), Vector2(0.1, 0.1))

	# 2. Land dust — jump_land_dust.png, one-shot, 12 fps
	var land_sf: SpriteFrames = make_dust_frames.call(E + "jump_land_dust.png", "land", 5, 12.0, false)
	_dust_land = make_dust_sprite.call("DustLand", land_sf, Vector2(0, feet_y), Vector2(0.125, 0.125))
	_dust_land.animation_finished.connect(_on_land_dust_finished)

	# 3. Wall dust — wall_dust.png, looping, 10 fps
	var wall_sf: SpriteFrames = make_dust_frames.call(E + "wall_dust.png", "wall", 6, 10.0, true)
	_dust_wall = make_dust_sprite.call("DustWall", wall_sf, Vector2.ZERO, Vector2(0.125, 0.125))

	# 4. Dash dust — floor_dash_dust.png, one-shot, 15 fps
	var dash_sf: SpriteFrames = make_dust_frames.call(E + "floor_dash_dust.png", "dash", 7, 15.0, false)
	_dust_dash = make_dust_sprite.call("DustDash", dash_sf, Vector2(0, feet_y), Vector2(0.125, 0.125))
	_dust_dash.animation_finished.connect(_on_dash_dust_finished)


func update(player: CharacterBody2D, landed: bool, is_wall_sliding: bool, dash_timer: float, dash_direction: float) -> void:
	var on_floor := player.is_on_floor()
	var feet_y := 9.0

	# --- Run dust: play when running on ground, not dashing ---
	var is_running: bool = on_floor and abs(player.velocity.x) > 30 and dash_timer <= 0.0
	if is_running:
		_dust_run.flip_h = player.velocity.x > 0.0
		_dust_run.position = Vector2(-sign(player.velocity.x) * 4.0, feet_y)
		if not _dust_run.visible:
			_dust_run.visible = true
			_dust_run.play("run")
	else:
		if _dust_run.visible:
			_dust_run.visible = false
			_dust_run.stop()

	# --- Land dust: one-shot on landing ---
	if landed:
		_dust_land.position = Vector2(0, feet_y)
		_dust_land.visible = true
		_dust_land.frame = 0
		_dust_land.play("land")

	# --- Wall dust: loop while wall sliding ---
	if is_wall_sliding:
		var wn := player.get_wall_normal()
		_dust_wall.position = Vector2(-wn.x * 6.0, -2.0)
		_dust_wall.flip_h = wn.x > 0.0
		if not _dust_wall.visible:
			_dust_wall.visible = true
			_dust_wall.play("wall")
	else:
		if _dust_wall.visible:
			_dust_wall.visible = false
			_dust_wall.stop()

	# --- Dash dust: one-shot at dash start, at feet ---
	var is_dashing := dash_timer > 0.0
	if is_dashing and not _was_dashing and on_floor:
		_dust_dash.flip_h = dash_direction > 0.0
		_dust_dash.position = Vector2(-dash_direction * 8.0, feet_y)
		_dust_dash.visible = true
		_dust_dash.frame = 0
		_dust_dash.play("dash")
	_was_dashing = is_dashing


func _on_land_dust_finished() -> void:
	_dust_land.visible = false


func _on_dash_dust_finished() -> void:
	_dust_dash.visible = false
