extends Node2D

const _RoomData := preload("res://scripts/room_data.gd")

const SOLID_COLOR := Color(0, 0, 0, 0)
const HAZARD_COLOR := Color(0.8, 0.2, 0.2)
const GOAL_COLOR := Color(0.333, 0.8, 0.333)

var current_room_index: int = 0
var room_geometry: Node2D
var props_container: Node2D
var hud_node: Node


@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	_setup_parallax_background()

	room_geometry = Node2D.new()
	room_geometry.name = "RoomGeometry"
	add_child(room_geometry)

	props_container = Node2D.new()
	props_container.name = "Props"
	add_child(props_container)

	# Create HUD
	var hud_script := load("res://scripts/hud.gd")
	hud_node = CanvasLayer.new()
	hud_node.set_script(hud_script)
	hud_node.name = "HUD"
	add_child(hud_node)

	# === WEATHER SYSTEM ===

	# Shared raindrop texture (thin 1x8 white streak)
	var drop_img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	drop_img.fill(Color.WHITE)
	var drop_tex := ImageTexture.create_from_image(drop_img)

	# --- Layer 1: Falling rain (child of Camera2D) ---
	var rain := CPUParticles2D.new()
	rain.name = "Rain"
	rain.emitting = true
	rain.amount = 450
	rain.lifetime = 0.8
	rain.texture = drop_tex
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(500, 10)
	rain.direction = Vector2(-0.2, 1.0)
	rain.spread = 5.0
	rain.gravity = Vector2(-30, 900)
	rain.initial_velocity_min = 400.0
	rain.initial_velocity_max = 600.0
	rain.scale_amount_min = 0.3
	rain.scale_amount_max = 2.0
	rain.color = Color(0.7, 0.75, 0.85, 0.15)
	rain.position = Vector2(0, -280)
	rain.z_index = 10
	camera.add_child(rain)

	player.hit_hazard.connect(_on_hazard)

	load_room(0)


func _setup_parallax_background() -> void:
	var bg := ParallaxBackground.new()
	bg.name = "ParallaxBackground"
	add_child(bg)

	# Scale to fill 450px viewport height from 320px source images
	var bg_scale := 450.0 / 320.0
	var scaled_width := 640.0 * bg_scale

	var P := "res://assets/backgrounds/dark_forest/"

	# Layers ordered back-to-front: 0 (sky) through 13 (foreground frame)
	# motion_scale.x spreads evenly from 0.0 (static sky) to 1.05 (foreground)
	var layers := [
		["bg_sky",      P + "0.png",              0.0],
		["bg_far_1",    P + "1.png",              0.1],
		["bg_far_2",    P + "2.png",              0.2],
		["bg_mid_1",    P + "3.png",              0.3],
		["bg_mid_2",    P + "4.png",              0.4],
		["bg_mid_3",    P + "5.png",              0.5],
		["bg_near_1",   P + "6.png",              0.6],
		["bg_near_2",   P + "7.png",              0.7],
		["bg_near_3",   P + "8.png",              0.8],
		["bg_closest",  P + "9.png",              0.9],
		["bg_debris",   P + "12.png",             1.0],
	]

	for layer_def in layers:
		var layer_name: String = layer_def[0]
		var tex_path: String = layer_def[1]
		var scroll_x: float = layer_def[2]

		var layer := ParallaxLayer.new()
		layer.name = layer_name
		layer.motion_scale = Vector2(scroll_x, 0.0)
		layer.motion_mirroring = Vector2(scaled_width, 0.0)
		bg.add_child(layer)

		var sprite := Sprite2D.new()
		sprite.texture = load(tex_path) as Texture2D
		sprite.centered = false
		sprite.scale = Vector2(bg_scale, bg_scale)
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		layer.add_child(sprite)

	# Floor layer — world-space, locked to camera at motion_scale (1,1)
	# so it feels like solid ground. Positioned so the green vegetation
	# aligns with the collision surface at y=640.
	var floor_layer := ParallaxLayer.new()
	floor_layer.name = "bg_floor"
	floor_layer.motion_scale = Vector2(1.0, 1.0)
	floor_layer.motion_mirroring = Vector2(scaled_width, 0.0)
	bg.add_child(floor_layer)

	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = load(P + "10-(floor).png") as Texture2D
	floor_sprite.centered = false
	floor_sprite.scale = Vector2(bg_scale, bg_scale)
	floor_sprite.position.y = 457.0  # 640 - (130 * bg_scale) — aligns vegetation with ground
	floor_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_layer.add_child(floor_sprite)

	# Light rays overlay — additive blend, slow drift, low opacity
	var light_layer := ParallaxLayer.new()
	light_layer.name = "bg_light"
	light_layer.motion_scale = Vector2(0.3, 0.0)
	light_layer.motion_mirroring = Vector2(scaled_width, 0.0)
	bg.add_child(light_layer)

	var light_sprite := Sprite2D.new()
	light_sprite.texture = load(P + "11---light.png") as Texture2D
	light_sprite.centered = false
	light_sprite.scale = Vector2(bg_scale, bg_scale)
	light_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	light_sprite.modulate = Color(1.0, 1.0, 1.0, 0.15)
	var light_mat := CanvasItemMaterial.new()
	light_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light_sprite.material = light_mat
	light_layer.add_child(light_sprite)


func load_room(index: int) -> void:
	current_room_index = index
	var room: Dictionary = _RoomData.ROOMS[index]

	# Clear old geometry and props
	for child in room_geometry.get_children():
		child.queue_free()
	for child in props_container.get_children():
		child.queue_free()

	# Wait a frame for queue_free to process
	await get_tree().process_frame

	# Build solids
	for s in room.solids:
		_create_solid(s.x, s.y, s.w, s.h)

	# Build moving platforms
	for mp in room.moving_platforms:
		_create_moving_platform(mp)

	# Build crumbling platforms
	for cp in room.crumbling_platforms:
		_create_crumbling_platform(cp)

	# Build hazards
	for h in room.hazards:
		_create_hazard(h.x, h.y, h.w, h.h)

	# Build goal
	var g: Dictionary = room.goal
	_create_goal(g.x, g.y, g.w, g.h)

	# Build checkpoint
	if room.has("checkpoint"):
		_create_checkpoint(room.checkpoint)

	# Room-specific props
	if index == 0:
		_setup_room1_props()

	# Set camera limits
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = room.width
	camera.limit_bottom = room.height

	# Set player spawn
	player.set_spawn(room.spawn)
	player.fall_respawn_y = room.fall_respawn_y
	player.global_position = room.spawn
	player.reset_abilities()

	# Update HUD
	hud_node.set_room_name(room.name, index)
	hud_node.set_hints(room.get("hints", []))


func _setup_room1_props() -> void:
	# Ground ColorRect removed — parallax floor layer (10-(floor).png) serves as visual ground.
	# Collision StaticBody2D at y=640 is created by _create_solid() from room data.

	# Zone 1 boundary wall — invisible, blocks player at x=900
	var wall := StaticBody2D.new()
	wall.name = "zone_1_boundary"
	wall.position = Vector2(900, 360)  # centered vertically in 720px room
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 720)
	var col := CollisionShape2D.new()
	col.shape = shape
	wall.add_child(col)
	room_geometry.add_child(wall)


func _create_solid(x: float, y: float, w: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x + w / 2.0, y + h / 2.0)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)

	room_geometry.add_child(body)


func _create_hazard(x: float, y: float, w: float, h: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x + w / 2.0, y + h / 2.0)
	area.collision_layer = 0
	area.collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)

	var rect := ColorRect.new()
	rect.position = Vector2(-w / 2.0, -h / 2.0)
	rect.size = Vector2(w, h)
	rect.color = HAZARD_COLOR
	area.add_child(rect)

	area.body_entered.connect(_on_hazard_body_entered)
	room_geometry.add_child(area)


func _on_hazard_body_entered(body: Node2D) -> void:
	if body == player:
		_on_hazard()


func _create_goal(x: float, y: float, w: float, h: float) -> void:
	var area := Area2D.new()
	area.position = Vector2(x + w / 2.0, y + h / 2.0)
	area.collision_layer = 0
	area.collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)

	var rect := ColorRect.new()
	rect.position = Vector2(-w / 2.0, -h / 2.0)
	rect.size = Vector2(w, h)
	rect.color = GOAL_COLOR
	area.add_child(rect)

	area.body_entered.connect(_on_goal_body_entered)
	room_geometry.add_child(area)


func _on_goal_body_entered(body: Node2D) -> void:
	if body == player:
		_on_goal_reached()


func _create_moving_platform(data: Dictionary) -> void:
	var mp_script := load("res://scripts/moving_platform.gd")
	var mp := AnimatableBody2D.new()
	mp.set_script(mp_script)
	room_geometry.add_child(mp)
	mp.setup(data.start, data.end, data.width, data.height, data.speed, data.pause)


func _create_crumbling_platform(data: Dictionary) -> void:
	var cp_script := load("res://scripts/crumbling_platform.gd")
	var cp := Node2D.new()
	cp.set_script(cp_script)
	cp.position = Vector2(data.x, data.y)
	cp.setup(data.x, data.y, data.w, data.h, data.shake, data.respawn)
	room_geometry.add_child(cp)


func _create_checkpoint(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	var col := CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)

	# Small visual marker
	var rect := ColorRect.new()
	rect.position = Vector2(-4, -8)
	rect.size = Vector2(8, 16)
	rect.color = Color(0.4, 0.8, 1.0, 0.6)
	area.add_child(rect)

	area.body_entered.connect(_on_checkpoint_entered)
	room_geometry.add_child(area)


func _on_checkpoint_entered(_body: Node2D) -> void:
	if _body == player:
		var room: Dictionary = _RoomData.ROOMS[current_room_index]
		if room.has("checkpoint"):
			player.activate_checkpoint(room.checkpoint)


func _on_goal_reached() -> void:
	var next_index := (current_room_index + 1) % _RoomData.ROOMS.size()
	load_room(next_index)


func _on_hazard() -> void:
	player.respawn()
	hud_node.flash_respawn()
