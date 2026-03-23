extends Node2D

const _RoomData := preload("res://scripts/room_data.gd")

const SOLID_COLOR := Color(0, 0, 0, 0)
const HAZARD_COLOR := Color(0.8, 0.2, 0.2)
const GOAL_COLOR := Color(0.333, 0.8, 0.333)

const TILE_SIZE := 64
var _tileset_tex: Texture2D

var current_room_index: int = 0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var room_geometry: Node2D = $RoomGeometry
@onready var props_container: Node2D = $Props
@onready var bg_container: Node2D = $Background
@onready var mg_container: Node2D = $Midground
@onready var fg_container: Node2D = $Foreground
@onready var hud_node: CanvasLayer = $HUD
@onready var rain: CPUParticles2D = $Player/Camera2D/Rain


func _ready() -> void:
	# Rain texture — generated at runtime (1x8 white streak)
	var drop_img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	drop_img.fill(Color.WHITE)
	rain.texture = ImageTexture.create_from_image(drop_img)

	_tileset_tex = load("res://assets/tilesets/mountain_pass/tileset 64x64.png") as Texture2D

	player.hit_hazard.connect(_on_hazard)

	load_room(0)


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
		# Add visual ground tiles for wide ground solids
		if s.w > 200:
			_create_ground_tiles(s.x, s.y, s.w)

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


func _create_ground_tiles(gx: float, gy: float, gw: float) -> void:
	# Tileset atlas coords (col, row) in 12x12 grid of 64x64 tiles
	# Surface edge: row 0 — thin rocky top edge (content at y=59-63 in tile)
	# Fill: rows 7-10 — solid dark rock
	var surface_tiles := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	# Row 10 tiles: brightest and most uniform rock texture (all avg 17-18)
	var fill_tiles := [
		Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10),
		Vector2i(4, 10), Vector2i(7, 10), Vector2i(8, 10), Vector2i(9, 10),
	]

	var cols := int(ceil(gw / TILE_SIZE))
	var container := Node2D.new()
	container.name = "GroundTiles"
	container.z_index = -1
	room_geometry.add_child(container)

	# Surface edge row: one tile above ground level
	for c in range(cols):
		var atlas_coord: Vector2i = surface_tiles[c % surface_tiles.size()]
		var sprite := _make_tile_sprite(atlas_coord)
		sprite.position = Vector2(gx + c * TILE_SIZE, gy - TILE_SIZE)
		container.add_child(sprite)

	# Fill rows: at ground level and below (2 rows = 128px)
	for row_idx in range(2):
		for c in range(cols):
			var atlas_coord: Vector2i = fill_tiles[(c + row_idx * 7) % fill_tiles.size()]
			var sprite := _make_tile_sprite(atlas_coord)
			sprite.position = Vector2(gx + c * TILE_SIZE, gy + row_idx * TILE_SIZE)
			container.add_child(sprite)

	print("Ground tiles: surface=", surface_tiles, " fill=", fill_tiles.slice(0, 4), "...")
	print("  ", cols, " columns, 3 rows (surface + 2 fill), from y=", gy - TILE_SIZE, " to y=", gy + 2 * TILE_SIZE)


func _make_tile_sprite(atlas_coord: Vector2i) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = _tileset_tex
	atlas.region = Rect2(atlas_coord.x * TILE_SIZE, atlas_coord.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


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
