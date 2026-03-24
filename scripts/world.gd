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
@onready var rain_splash: CPUParticles2D = $Player/Camera2D/RainSplash

var _canvas_modulate: CanvasModulate
var _base_darkness := Color(0.05, 0.05, 0.08, 1.0)
var _lightning_timer: float = 0.0


func _ready() -> void:
	# Rain texture — generated at runtime (1x8 white streak)
	var drop_img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	drop_img.fill(Color.WHITE)
	rain.texture = ImageTexture.create_from_image(drop_img)

	# Splash texture — tiny 2x2 white dot
	var splash_img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	splash_img.fill(Color.WHITE)
	rain_splash.texture = ImageTexture.create_from_image(splash_img)

	_tileset_tex = load("res://assets/tilesets/mountain_pass/tileset 64x64.png") as Texture2D

	player.hit_hazard.connect(_on_hazard)

	# Darken parallax background separately for moodier atmosphere
	var parallax_bg := $ParallaxBackground
	var bg_tint := Color(0.5, 0.5, 0.55, 1.0)
	for layer in parallax_bg.get_children():
		if layer is ParallaxLayer:
			layer.modulate = bg_tint
	print("ParallaxBackground layers modulate: ", bg_tint)

	# Dark atmosphere — darken everything, player/campfire lights punch through
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "DarkAtmosphere"
	_canvas_modulate.color = _base_darkness
	add_child(_canvas_modulate)
	print("CanvasModulate: ", _canvas_modulate.color)

	hud_node.set_player(player)

	# Lightning timer
	_lightning_timer = randf_range(8.0, 20.0)
	print("Lightning system: multi-burst via CanvasModulate, timer=", _lightning_timer, "s")

	load_room(0)

	print("Player health: ", player.current_health, "/", player.MAX_HEALTH)
	print("Shield blocks attacks: YES")


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

	# Zone 1 boundary wall — invisible, blocks player at x=2400
	var wall := StaticBody2D.new()
	wall.name = "zone_1_boundary"
	wall.set_collision_layer_value(1, true)
	wall.set_collision_layer_value(3, true)
	wall.position = Vector2(2400, 360)  # centered vertically in 720px room
	print("Zone 1 boundary: 900 -> 2400")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 720)
	var col := CollisionShape2D.new()
	col.shape = shape
	wall.add_child(col)
	room_geometry.add_child(wall)

	# Campfire with roasting pig
	_create_campfire(Vector2(350, 640))

	# Ghouls
	var ghoul_scene := load("res://scenes/enemies/Ghoul.tscn") as PackedScene
	var ghoul_positions := [Vector2(800, 631), Vector2(1400, 631), Vector2(2000, 631)]
	for pos in ghoul_positions:
		var ghoul := ghoul_scene.instantiate()
		ghoul.global_position = pos
		room_geometry.add_child(ghoul)
	print("Spawned ", ghoul_positions.size(), " ghouls")


func _create_campfire(pos: Vector2) -> void:
	var campfire := Node2D.new()
	campfire.name = "Campfire"
	campfire.position = pos
	mg_container.add_child(campfire)

	# Fire — animated spritesheet: 432x38, 12 frames of 36x38
	var fire_path := "res://assets/props/room_1/zone_1/midground/animated/Custom Fires-Wild.png"
	var fire_tex := load(fire_path) as Texture2D
	var FRAME_W := 36
	var FRAME_H := 38
	var frame_count := int(fire_tex.get_width()) / FRAME_W

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("burn")
	sf.set_animation_speed("burn", 10.0)
	sf.set_animation_loop("burn", true)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = fire_tex
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		sf.add_frame("burn", atlas)

	var sc := 1.2
	var fire := AnimatedSprite2D.new()
	fire.name = "Fire"
	fire.sprite_frames = sf
	fire.scale = Vector2(sc, sc)
	fire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fire.position = Vector2(0, -FRAME_H * sc / 2.0)  # bottom of fire at ground
	fire.play("burn")
	campfire.add_child(fire)

	# Pig on spit — just above the flames
	var pig_tex := load("res://assets/props/room_1/zone_1/midground/pig.png") as Texture2D
	var pig := Sprite2D.new()
	pig.name = "Pig"
	pig.texture = pig_tex
	pig.scale = Vector2(sc, sc)
	pig.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pig.position = Vector2(0, -FRAME_H * sc * 0.55)  # sitting just above fire
	campfire.add_child(pig)

	# Campfire light — warm orange glow
	var fire_light := PointLight2D.new()
	fire_light.name = "FireLight"
	print("FireLight BEFORE: color=Color(1.0, 0.7, 0.3), energy=1.2")
	fire_light.color = Color(1.0, 0.5, 0.2)
	fire_light.energy = 1.5
	print("FireLight AFTER: color=", fire_light.color, ", energy=", fire_light.energy)
	fire_light.texture = _make_light_texture()
	fire_light.texture_scale = 1.5
	fire_light.position = Vector2(0, -FRAME_H * sc * 0.5)
	fire_light.shadow_enabled = false
	fire_light.blend_mode = Light2D.BLEND_MODE_ADD
	campfire.add_child(fire_light)

	print("Campfire: Custom Fires-Wild.png ", fire_tex.get_width(), "x", fire_tex.get_height(), ", ", frame_count, " frames of ", FRAME_W, "x", FRAME_H)
	print("  scale=", sc, " pos=", pos, " fire=", fire.position, " pig=", pig.position)


func _create_ground_tiles(gx: float, gy: float, gw: float) -> void:
	# Surface edge: row 0, col 2 — thin rocky top edge
	var surface_coord := Vector2i(2, 0)
	# ONE fill tile: (4,10) — brightest uniform rock, avg brightness 18.8
	var fill_coord := Vector2i(4, 10)

	var cols: int = int(ceil(gw / float(TILE_SIZE)))
	var fill_rows: int = 3  # 3 rows of fill = 192px below surface
	var total_rows: int = 1 + fill_rows  # 1 surface + 3 fill
	var expected: int = cols * total_rows
	var placed: int = 0

	var container := Node2D.new()
	container.name = "GroundTiles"
	container.z_index = -1
	room_geometry.add_child(container)

	# Brute force: every cell gets a tile, no exceptions
	for r in range(total_rows):
		var tile_y: float = gy - TILE_SIZE + r * TILE_SIZE
		for c in range(cols):
			var tile_x: float = gx + c * TILE_SIZE
			var coord: Vector2i = surface_coord if r == 0 else fill_coord
			var sprite := _make_tile_sprite(coord)
			sprite.position = Vector2(tile_x, tile_y)
			container.add_child(sprite)
			placed += 1

	print("Ground tiles: ", cols, "x", total_rows, " = ", placed, " placed (expected ", expected, ")")
	print("  X: ", gx, " to ", gx + cols * TILE_SIZE, "  Y: ", gy - TILE_SIZE, " to ", gy - TILE_SIZE + total_rows * TILE_SIZE)


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
	# Ground on layers 1 + 3 so both player (mask 1|3) and enemies (mask 3) collide
	body.set_collision_layer_value(1, true)
	body.set_collision_layer_value(3, true)

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


func _make_light_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - dist / radius, 0.0, 1.0)
			alpha = alpha * alpha  # quadratic falloff for soft edges
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_do_lightning_flash()
		_lightning_timer = randf_range(8.0, 20.0)


func _do_lightning_flash() -> void:
	var num_bursts := randi_range(2, 3)
	for i in num_bursts:
		var intensity := randf_range(0.6, 0.85)
		if i == 0:
			intensity = randf_range(0.85, 1.0)
		var flash_color := Color(intensity, intensity, intensity + 0.1, 1.0)
		# Quick flash up
		var tween := create_tween()
		tween.tween_property(_canvas_modulate, "color", flash_color, randf_range(0.03, 0.05))
		await tween.finished
		# Slower fade down
		tween = create_tween()
		tween.tween_property(_canvas_modulate, "color", _base_darkness, randf_range(0.08, 0.15))
		await tween.finished
		# Brief pause between bursts
		if i < num_bursts - 1:
			await get_tree().create_timer(randf_range(0.05, 0.1)).timeout
	print("Lightning flash - peak intensity: ", num_bursts, " bursts")


func _on_hazard() -> void:
	player.respawn()
	hud_node.flash_respawn()
