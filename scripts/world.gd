extends Node2D

const _RoomData := preload("res://scripts/room_data.gd")

const SOLID_COLOR := Color(0, 0, 0, 0)
const HAZARD_COLOR := Color(0.8, 0.2, 0.2)
const GOAL_COLOR := Color(0.333, 0.8, 0.333)

var current_room_index: int = 0
var room_geometry: Node2D
var props_container: Node2D
var hud_node: Node

# Lighting references for pulsing
var player_glow: PointLight2D
var campfire_light: PointLight2D
var lamppost_light: PointLight2D
var _light_tex: Texture2D
var _time: float = 0.0

# Lamppost flicker state machine
var _lamp_flicker_state: String = "idle"  # idle, double_flicker, brownout, blackout
var _lamp_flicker_timer: float = 0.0
var _lamp_flicker_step: int = 0
var _lamp_base_energy: float = 0.8

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

	# Darkness overlay — deeper darkness for ominous atmosphere
	var canvas_mod := CanvasModulate.new()
	canvas_mod.name = "DarknessOverlay"
	canvas_mod.color = Color(0.08, 0.09, 0.14, 1.0)
	add_child(canvas_mod)

	# Shared radial light texture — programmatic ImageTexture (GL Compat safe)
	var light_size := 256
	var light_img := Image.create(light_size, light_size, false, Image.FORMAT_RGBA8)
	var light_center := Vector2(127.5, 127.5)
	var light_radius := 128.0
	for ly in range(light_size):
		for lx in range(light_size):
			var d := Vector2(lx, ly).distance_to(light_center) / light_radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a  # quadratic falloff
			light_img.set_pixel(lx, ly, Color(1, 1, 1, a))
	_light_tex = ImageTexture.create_from_image(light_img)

	# --- Player glow — warm amber spotlight ---
	player_glow = PointLight2D.new()
	player_glow.name = "PlayerGlow"
	player_glow.color = Color(1.0, 0.85, 0.6, 1.0)
	player_glow.energy = 1.8
	player_glow.blend_mode = PointLight2D.BLEND_MODE_ADD
	player_glow.shadow_enabled = false
	player_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	player_glow.texture_scale = 1.0
	player_glow.texture = _light_tex
	player.add_child(player_glow)

	# === WEATHER SYSTEM ===

	# Shared raindrop texture (thin 1x8 white streak)
	var drop_img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	drop_img.fill(Color.WHITE)
	var drop_tex := ImageTexture.create_from_image(drop_img)

	# Shared splash texture (small 3x3 white dot)
	var splash_img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	splash_img.fill(Color.WHITE)
	var splash_tex := ImageTexture.create_from_image(splash_img)

	# Shared mist texture (soft 16x16 radial blob)
	var mist_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var center := Vector2(7.5, 7.5)
	for my in range(16):
		for mx in range(16):
			var dist := Vector2(mx, my).distance_to(center) / 7.5
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha *= alpha  # quadratic falloff for softness
			mist_img.set_pixel(mx, my, Color(1, 1, 1, alpha))
	var mist_tex := ImageTexture.create_from_image(mist_img)

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

	# --- Layer 2: Ground splashes (child of World, at ground level) ---
	var splash := CPUParticles2D.new()
	splash.name = "RainSplash"
	splash.emitting = true
	splash.amount = 90
	splash.lifetime = 0.3
	splash.texture = splash_tex
	splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	splash.emission_rect_extents = Vector2(3300, 2)
	splash.direction = Vector2(0, -1)
	splash.spread = 30.0
	splash.gravity = Vector2(0, 200)
	splash.initial_velocity_min = 20.0
	splash.initial_velocity_max = 50.0
	splash.scale_amount_min = 0.3
	splash.scale_amount_max = 0.8
	splash.color = Color(0.8, 0.85, 0.9, 0.2)
	splash.position = Vector2(3300, 638)
	splash.z_index = 5
	add_child(splash)

	# --- Layer 3: Low-lying atmospheric mist (child of Camera2D) ---
	var mist := CPUParticles2D.new()
	mist.name = "Mist"
	mist.emitting = true
	mist.amount = 12
	mist.lifetime = 4.0
	mist.texture = mist_tex
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(450, 30)
	mist.direction = Vector2(-1, 0)
	mist.spread = 15.0
	mist.gravity = Vector2.ZERO
	mist.initial_velocity_min = 5.0
	mist.initial_velocity_max = 15.0
	mist.scale_amount_min = 3.0
	mist.scale_amount_max = 5.0
	mist.color = Color(0.6, 0.65, 0.7, 0.08)
	mist.position = Vector2(0, 160)
	mist.z_index = 4
	camera.add_child(mist)

	player.hit_hazard.connect(_on_hazard)

	load_room(0)


func _process(delta: float) -> void:
	_time += delta

	# Player glow pulse — gentle sin wave between 1.6 and 2.0 over ~2s
	player_glow.energy = 1.8 + 0.2 * sin(_time * PI)

	# Purple campfire flicker — 1.2-1.8 over ~0.6s with randomness
	if is_instance_valid(campfire_light):
		var flicker := sin(_time * PI / 0.3) * 0.3
		flicker += sin(_time * PI / 0.13) * 0.1  # high-freq jitter
		campfire_light.energy = 1.5 + flicker

	# Lamppost flicker — organic dying-fluorescent-bulb effect
	if is_instance_valid(lamppost_light):
		_update_lamppost_flicker(delta)


func _update_lamppost_flicker(delta: float) -> void:
	_lamp_flicker_timer -= delta

	if _lamp_flicker_state == "idle":
		# Subtle continuous jitter while idle
		lamppost_light.energy = _lamp_base_energy + randf_range(-0.05, 0.05)

		if _lamp_flicker_timer <= 0.0:
			# Roll for a flicker event each cycle (~0.1s ticks)
			_lamp_flicker_timer = 0.1
			var roll := randf()
			if roll < 0.002:  # ~2% per second: full blackout
				_lamp_flicker_state = "blackout"
				_lamp_flicker_timer = randf_range(0.5, 1.0)
				lamppost_light.energy = 0.0
			elif roll < 0.007:  # ~5% per second: brownout
				_lamp_flicker_state = "brownout"
				_lamp_flicker_step = 0
				_lamp_flicker_timer = 0.3
			elif roll < 0.017:  # ~10% per second: double flicker
				_lamp_flicker_state = "double_flicker"
				_lamp_flicker_step = 0
				_lamp_flicker_timer = 0.05

	elif _lamp_flicker_state == "double_flicker":
		if _lamp_flicker_timer <= 0.0:
			_lamp_flicker_step += 1
			if _lamp_flicker_step == 1:
				lamppost_light.energy = 0.2
				_lamp_flicker_timer = 0.05
			elif _lamp_flicker_step == 2:
				lamppost_light.energy = _lamp_base_energy
				_lamp_flicker_timer = 0.05
			elif _lamp_flicker_step == 3:
				lamppost_light.energy = 0.1
				_lamp_flicker_timer = 0.08
			else:
				lamppost_light.energy = _lamp_base_energy
				_lamp_flicker_state = "idle"
				_lamp_flicker_timer = randf_range(0.5, 2.0)

	elif _lamp_flicker_state == "brownout":
		if _lamp_flicker_step == 0:
			# Dimming phase: lerp down over 0.3s
			var progress := 1.0 - (_lamp_flicker_timer / 0.3)
			lamppost_light.energy = lerpf(_lamp_base_energy, 0.3, clampf(progress, 0.0, 1.0))
			if _lamp_flicker_timer <= 0.0:
				_lamp_flicker_step = 1
				_lamp_flicker_timer = 0.2
		elif _lamp_flicker_step == 1:
			# Hold dim
			lamppost_light.energy = 0.3
			if _lamp_flicker_timer <= 0.0:
				# Snap back
				lamppost_light.energy = _lamp_base_energy
				_lamp_flicker_state = "idle"
				_lamp_flicker_timer = randf_range(1.0, 3.0)

	elif _lamp_flicker_state == "blackout":
		lamppost_light.energy = 0.0
		if _lamp_flicker_timer <= 0.0:
			lamppost_light.energy = _lamp_base_energy
			_lamp_flicker_state = "idle"
			_lamp_flicker_timer = randf_range(2.0, 5.0)


func _setup_parallax_background() -> void:
	var bg := ParallaxBackground.new()
	bg.name = "ParallaxBackground"
	add_child(bg)

	# Scale to fill 450px height from 384px source
	var bg_scale := 450.0 / 384.0
	var scaled_width := 576.0 * bg_scale

	var layers := [
		["sky",         "res://assets/backgrounds/bg.png",  0.0],
		["far_trees",   "res://assets/backgrounds/bg1.png", 0.1],
		["mid_trees",   "res://assets/backgrounds/bg2.png", 0.2],
		["near_trees",  "res://assets/backgrounds/bg3.png", 0.35],
		["foreground",  "res://assets/backgrounds/bg4.png", 0.5],
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
		layer.add_child(sprite)


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
	var ground_y := 640.0

	# =====================================================================
	# GROUND — simple dark ColorRect covering the ground collision area
	# =====================================================================
	var ground_rect := ColorRect.new()
	ground_rect.name = "Ground"
	ground_rect.position = Vector2(0, ground_y)
	ground_rect.size = Vector2(6600, 80)
	ground_rect.color = Color(0.094, 0.059, 0.024, 1.0)
	ground_rect.z_index = -2
	room_geometry.add_child(ground_rect)

	# --- Helper: place a prop with bottom edge at ground_y ---
	var place := func(path: String, x: float, sc: float, z: int) -> void:
		var tex := load(path) as Texture2D
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.position = Vector2(x, ground_y - tex.get_height() * sc + 1.0 * sc)
		sprite.scale = Vector2(sc, sc)
		sprite.z_index = z
		props_container.add_child(sprite)

	# Shorthand paths
	var P := "res://assets/props/"

	# =====================================================================
	# ZONE A — FOREST APPROACH (x 0 - 2100)
	# Dense forest the player walks through toward the camp
	# =====================================================================

	# --- Far background trees (z=-3) — depth layer ---
	place.call(P + "camp tree2.png",  60.0,   3.5, -3)
	place.call(P + "camp stree.png",  350.0,  3.2, -3)
	place.call(P + "camp tree2.png",  680.0,  3.0, -3)
	place.call(P + "camp stree.png",  1050.0, 3.4, -3)
	place.call(P + "camp tree2.png",  1400.0, 3.1, -3)
	place.call(P + "camp stree.png",  1750.0, 3.3, -3)

	# --- Closer trees (z=-2) — mid layer ---
	place.call(P + "camp stree.png",  180.0,  3.0, -2)
	place.call(P + "camp tree2.png",  520.0,  3.3, -2)
	place.call(P + "camp stree.png",  900.0,  2.8, -2)
	place.call(P + "camp tree2.png",  1220.0, 3.1, -2)
	place.call(P + "camp stree.png",  1580.0, 2.9, -2)
	place.call(P + "camp tree2.png",  1900.0, 3.2, -2)

	# --- Large bushes at tree bases ---
	place.call(P + "large_bush1.png",    140.0,  2.8, -2)
	place.call(P + "large_bush1.png",    870.0,  2.6, -2)
	place.call(P + "large_bush1.png",    1720.0, 2.7, -2)

	# --- Medium bushes scattered ---
	place.call(P + "medium_bush_1.png",  70.0,   2.3, -1)
	place.call(P + "medium_bush_1.png",  620.0,  2.4, -1)
	place.call(P + "medium_bush_1.png",  1280.0, 2.5, -1)
	place.call(P + "medium_bush_1.png",  1960.0, 2.0, -1)

	# --- Small bushes as ground cover ---
	place.call(P + "small_bush_1.png",   250.0,  2.0, -1)
	place.call(P + "small_bush2.png",    740.0,  1.7, -1)
	place.call(P + "small_bush_1.png",   1100.0, 1.9, -1)
	place.call(P + "small_bush2.png",    1460.0, 1.8, -1)
	place.call(P + "small_bush_1.png",   1820.0, 1.6, -1)

	# --- Tiny bushes / ground litter ---
	place.call(P + "tiny_bush3.png",     400.0,  1.5, 0)
	place.call(P + "tiny_bush1.png",     820.0,  2.0, 0)
	place.call(P + "tiny_bush4.png",     1330.0, 1.8, 0)
	place.call(P + "tiny_bush3.png",     1880.0, 1.7, 0)
	place.call(P + "tiny_bush4.png",     2050.0, 1.9, 0)

	# --- Rocks scattered on ground ---
	place.call(P + "medium_rock1.png",   200.0,  2.2, -1)
	place.call(P + "tiny_rock2.png",     660.0,  1.6, 0)
	place.call(P + "big_rock1.png",      1150.0, 2.0, -1)
	place.call(P + "tiny_rock1.png",     1500.0, 1.7, 0)
	place.call(P + "medium_rock1.png",   1700.0, 2.3, -1)
	place.call(P + "tiny_rock1.png",     1950.0, 1.5, 0)

	# --- Sticks and bones as debris ---
	place.call(P + "stick2.png",         550.0,  1.6, 0)
	place.call(P + "bones1.png",         790.0,  2.0, 0)
	place.call(P + "bones2.png",         1430.0, 1.8, 0)
	place.call(P + "stick1.png",         1780.0, 1.5, 0)

	# --- Signs along the path ---
	place.call(P + "sign2.png",          450.0,  2.3, -1)   # tall directional sign
	place.call(P + "tiny_sign1.png",     1070.0, 2.0, -1)   # small marker
	place.call(P + "sign1.png",          1600.0, 2.2, -1)   # another sign
	place.call(P + "sign3.png",          2000.0, 2.0, -1)   # near camp entrance

	# =====================================================================
	# ZONE B — THE CAMP (x 2100 - 3050)
	# Existing camp props — shifted right by 2100 to center in extended level
	# =====================================================================
	var camp_x := 2100.0

	# Camp background trees (z=-3)
	place.call(P + "camp stree.png",  camp_x + 20.0,  3.0, -3)
	place.call(P + "camp tree2.png",  camp_x + 750.0, 3.5, -3)
	place.call(P + "camp stree.png",  camp_x + 560.0, 2.5, -3)

	# Storage area — boxes, barrel, fence
	place.call(P + "camp box1.png",          camp_x + 40.0,  2.5, -1)
	var box1_h := 16.0 * 2.5
	var box_stack := Sprite2D.new()
	box_stack.texture = load(P + "camp box2.png") as Texture2D
	box_stack.centered = false
	box_stack.scale = Vector2(2.5, 2.5)
	box_stack.position = Vector2(camp_x + 45.0, ground_y - box1_h - 16.0 * 2.5)
	box_stack.z_index = -1
	props_container.add_child(box_stack)
	place.call(P + "camp box4.png",          camp_x + 120.0, 2.5, -1)
	place.call(P + "camp scrazy_barrel.png", camp_x + 105.0, 2.5, -1)
	place.call(P + "camp stinybox1.png",     camp_x + 155.0, 2.0, -1)
	place.call(P + "campmetal_fence.png",    camp_x + 170.0, 2.5, -1)

	# Spawn area — lamppost
	place.call(P + "lamp_post.png",                camp_x + 280.0, 3.0, -1)
	place.call(P + "camp tiny_metal_fence.png",    camp_x + 330.0, 2.5, -1)

	# Debris / destruction
	place.call(P + "campbox8.png",           camp_x + 410.0, 2.5, -1)
	place.call(P + "camp spbox7.png",        camp_x + 440.0, 2.5, -1)
	place.call(P + "cambox3.png",            camp_x + 490.0, 2.0, -1)
	place.call(P + "camptinybox2.png",       camp_x + 520.0, 2.0, -1)
	place.call(P + "camp scrazy_barrel.png", camp_x + 540.0, 2.5, -1)

	# Tech/comms area
	place.call(P + "camcrazy_antena2.png",   camp_x + 600.0, 3.0, -1)
	place.call(P + "cagenerator.png",        camp_x + 580.0, 2.5, -1)
	place.call(P + "camgenerator2.png",      camp_x + 650.0, 2.5, -1)
	place.call(P + "camp box6.png",          camp_x + 670.0, 2.0, -1)

	# Rest area — tent, chairs, grill
	place.call(P + "camp spten.png",         camp_x + 710.0, 2.5, -2)
	place.call(P + "camp chair_l.png",       camp_x + 720.0, 2.5, -1)
	place.call(P + "camp grill.png",         camp_x + 755.0, 2.5, -1)
	place.call(P + "camp chair_r.png",       camp_x + 790.0, 2.5, -1)
	place.call(P + "camp sprtent4.png",      camp_x + 810.0, 2.5, -2)
	place.call(P + "campbox5.png",           camp_x + 850.0, 2.0, -1)

	# Transition bushes — blend camp edges into forest
	place.call(P + "small_bush2.png",        camp_x - 30.0,  1.8, -1)
	place.call(P + "tiny_bush4.png",         camp_x - 10.0,  1.6, 0)
	place.call(P + "small_bush_1.png",       camp_x + 880.0, 1.9, -1)
	place.call(P + "tiny_bush1.png",         camp_x + 910.0, 1.7, 0)
	place.call(P + "tiny_rock2.png",         camp_x - 50.0,  1.5, 0)
	place.call(P + "tiny_rock1.png",         camp_x + 900.0, 1.6, 0)

	# =====================================================================
	# ZONE C — FOREST BEYOND (x 3050 - 6600)
	# Sparser forest — thins out, more rocks and debris, hints of danger
	# =====================================================================
	var zone_c := 3050.0

	# --- Background trees (z=-3) — fewer than Zone A ---
	place.call(P + "camp tree2.png",  zone_c + 100.0,  3.3, -3)
	place.call(P + "camp stree.png",  zone_c + 550.0,  3.0, -3)
	place.call(P + "camp tree2.png",  zone_c + 1100.0, 3.4, -3)
	place.call(P + "camp stree.png",  zone_c + 1700.0, 3.1, -3)
	place.call(P + "camp tree2.png",  zone_c + 2300.0, 3.2, -3)
	place.call(P + "camp stree.png",  zone_c + 2900.0, 3.0, -3)
	place.call(P + "camp tree2.png",  zone_c + 3300.0, 3.5, -3)

	# --- Closer trees (z=-2) — sparser ---
	place.call(P + "camp stree.png",  zone_c + 300.0,  2.7, -2)
	place.call(P + "camp tree2.png",  zone_c + 800.0,  3.0, -2)
	place.call(P + "camp stree.png",  zone_c + 1400.0, 2.9, -2)
	place.call(P + "camp tree2.png",  zone_c + 2000.0, 3.1, -2)
	place.call(P + "camp stree.png",  zone_c + 2600.0, 2.8, -2)
	place.call(P + "camp tree2.png",  zone_c + 3100.0, 3.0, -2)

	# --- Large bushes — fewer, more spread out ---
	place.call(P + "large_bush1.png",    zone_c + 250.0,  2.7, -2)
	place.call(P + "large_bush1.png",    zone_c + 1500.0, 2.8, -2)
	place.call(P + "large_bush1.png",    zone_c + 3000.0, 2.9, -2)

	# --- Medium bushes ---
	place.call(P + "medium_bush_1.png",  zone_c + 600.0,  2.0, -1)
	place.call(P + "medium_bush_1.png",  zone_c + 1600.0, 2.1, -1)
	place.call(P + "medium_bush_1.png",  zone_c + 2100.0, 2.4, -1)
	place.call(P + "medium_bush_1.png",  zone_c + 2700.0, 2.0, -1)
	place.call(P + "medium_bush_1.png",  zone_c + 3200.0, 2.2, -1)

	# --- Small bushes ---
	place.call(P + "small_bush2.png",    zone_c + 450.0,  1.7, -1)
	place.call(P + "small_bush_1.png",   zone_c + 1300.0, 1.8, -1)
	place.call(P + "small_bush2.png",    zone_c + 1850.0, 1.9, -1)
	place.call(P + "small_bush_1.png",   zone_c + 2400.0, 1.7, -1)
	place.call(P + "small_bush2.png",    zone_c + 2850.0, 1.8, -1)
	place.call(P + "small_bush_1.png",   zone_c + 3350.0, 1.6, -1)

	# --- Tiny bushes / ground litter ---
	place.call(P + "tiny_bush3.png",     zone_c + 500.0,  1.8, 0)
	place.call(P + "tiny_bush1.png",     zone_c + 1150.0, 1.7, 0)
	place.call(P + "tiny_bush4.png",     zone_c + 1800.0, 1.6, 0)
	place.call(P + "tiny_bush3.png",     zone_c + 2500.0, 1.5, 0)
	place.call(P + "tiny_bush1.png",     zone_c + 3150.0, 1.9, 0)
	place.call(P + "tiny_bush4.png",     zone_c + 3400.0, 1.6, 0)

	# --- Rocks — more rocks than Zone A, increasingly rocky ---
	place.call(P + "big_rock1.png",      zone_c + 400.0,  2.2, -1)
	place.call(P + "big_rock2.png",      zone_c + 950.0,  2.0, -1)
	place.call(P + "medium_rock1.png",   zone_c + 700.0,  2.1, -1)
	place.call(P + "medium_rock1.png",   zone_c + 1250.0, 2.4, -1)
	place.call(P + "medium_rock1.png",   zone_c + 1900.0, 2.0, -1)
	place.call(P + "big_rock2.png",      zone_c + 2800.0, 2.3, -1)
	place.call(P + "big_rock1.png",      zone_c + 3250.0, 2.1, -1)
	place.call(P + "tiny_rock2.png",     zone_c + 650.0,  1.6, 0)
	place.call(P + "tiny_rock1.png",     zone_c + 1350.0, 1.5, 0)
	place.call(P + "tiny_rock2.png",     zone_c + 2050.0, 1.8, 0)
	place.call(P + "tiny_rock1.png",     zone_c + 2650.0, 1.9, 0)
	place.call(P + "tiny_rock2.png",     zone_c + 3350.0, 1.7, 0)

	# --- Sticks, bones, debris ---
	place.call(P + "stick2.png",         zone_c + 530.0,  1.5, 0)
	place.call(P + "bones1.png",         zone_c + 850.0,  2.0, 0)
	place.call(P + "stick1.png",         zone_c + 1550.0, 1.6, 0)
	place.call(P + "bones2.png",         zone_c + 2250.0, 1.7, 0)
	place.call(P + "bones1.png",         zone_c + 2900.0, 1.5, 0)
	place.call(P + "stick2.png",         zone_c + 3200.0, 1.8, 0)

	# --- Signs — broken/weathered, suggesting a dangerous path ---
	place.call(P + "sign1.png",          zone_c + 80.0,   2.2, -1)
	place.call(P + "tiny_sign2.png",     zone_c + 1000.0, 2.0, -1)
	place.call(P + "sign3.png",          zone_c + 1650.0, 2.3, -1)
	place.call(P + "tiny_sign1.png",     zone_c + 2300.0, 1.8, -1)
	place.call(P + "sign2.png",          zone_c + 3100.0, 2.5, -1)

	# =====================================================================
	# ORGANIC GROUND EDGE — mixed rocks, plants, sticks, debris
	# No asset repeats more than twice in a row. All z_index: -1.
	# 40-50% of each item's height sunk below ground_y. Varied y ±3-8px.
	# =====================================================================
	var edge_assets := [
		[P + "medium_rock1.png", 1.8, 2.5],   # 0: rock
		[P + "tiny_rock1.png",   1.5, 2.2],   # 1: rock
		[P + "tiny_rock2.png",   1.5, 2.2],   # 2: rock
		[P + "small_bush_1.png", 1.5, 2.0],   # 3: plant
		[P + "small_bush2.png",  1.5, 2.0],   # 4: plant
		[P + "stick1.png",       1.5, 2.0],   # 5: debris
		[P + "stick2.png",       1.5, 2.0],   # 6: debris
	]
	var edge_textures: Array = []
	for ea in edge_assets:
		edge_textures.append([load(ea[0]) as Texture2D, ea[1], ea[2]])

	var edge_rng := RandomNumberGenerator.new()
	edge_rng.seed = 99

	# Pre-build a shuffled sequence that never repeats an asset >2x in a row
	var ex := 20.0
	var last_idx := -1
	var repeat_count := 0
	while ex < 6600.0:
		var in_camp_e: bool = ex >= 2100.0 and ex <= 3050.0

		# Skip campfire exclusion zone
		if ex > 2440.0 and ex < 2640.0:
			ex += 200.0
			continue

		# Pick asset — prevent >2 consecutive uses of same index
		var ei := edge_rng.randi_range(0, edge_textures.size() - 1)
		if ei == last_idx:
			repeat_count += 1
			if repeat_count >= 2:
				# Force a different asset
				ei = (ei + edge_rng.randi_range(1, edge_textures.size() - 1)) % edge_textures.size()
				repeat_count = 0
		else:
			repeat_count = 0
		last_idx = ei

		var etex: Texture2D = edge_textures[ei][0]
		var esc_min: float = edge_textures[ei][1]
		var esc_max: float = edge_textures[ei][2]
		var esc := edge_rng.randf_range(esc_min, esc_max)

		var edge_sprite := Sprite2D.new()
		edge_sprite.texture = etex
		edge_sprite.centered = false
		edge_sprite.scale = Vector2(esc, esc)

		# Sink 40-50% below ground line
		var item_h := etex.get_height() * esc
		var sink_frac := edge_rng.randf_range(0.40, 0.50)
		var above_ground := item_h * (1.0 - sink_frac)

		# Vary y ±3-8px
		var y_jitter := edge_rng.randf_range(-8.0, 3.0)
		edge_sprite.position = Vector2(ex, ground_y - above_ground + y_jitter)
		edge_sprite.z_index = -1
		props_container.add_child(edge_sprite)

		# Irregular spacing: 100-300px, sparser in camp
		var edge_spacing: float
		if in_camp_e:
			edge_spacing = edge_rng.randf_range(200.0, 350.0)
		else:
			edge_spacing = edge_rng.randf_range(100.0, 300.0)
		ex += edge_spacing

	# =====================================================================
	# FOREGROUND SILHOUETTES — static dark shapes at level edges (world objects)
	# Each uses a DIFFERENT source asset. z_index: 10. Nearly black modulate.
	# =====================================================================
	var sil_color := Color(0.04, 0.05, 0.04, 0.9)

	# Far left edge: large_bush1 — partially off-screen left
	var sil_left := Sprite2D.new()
	sil_left.texture = load(P + "large_bush1.png") as Texture2D
	sil_left.centered = false
	sil_left.scale = Vector2(5.0, 5.0)
	sil_left.position = Vector2(-80.0, ground_y - sil_left.texture.get_height() * 5.0 + 30.0)
	sil_left.modulate = sil_color
	sil_left.z_index = 10
	props_container.add_child(sil_left)

	# Far right edge: camp tree2 — partially off-screen right
	var sil_right := Sprite2D.new()
	sil_right.texture = load(P + "camp tree2.png") as Texture2D
	sil_right.centered = false
	sil_right.scale = Vector2(5.0, 5.0)
	sil_right.position = Vector2(6600.0 - sil_right.texture.get_width() * 5.0 + 60.0, ground_y - sil_right.texture.get_height() * 5.0 + 20.0)
	sil_right.modulate = sil_color
	sil_right.z_index = 10
	props_container.add_child(sil_right)

	# Mid-forest accent: medium_bush_1 — Zone A, positioned high enough to not block gameplay
	var sil_mid := Sprite2D.new()
	sil_mid.texture = load(P + "medium_bush_1.png") as Texture2D
	sil_mid.centered = false
	sil_mid.scale = Vector2(4.0, 4.0)
	sil_mid.position = Vector2(1200.0, ground_y - sil_mid.texture.get_height() * 4.0 + 15.0)
	sil_mid.modulate = sil_color
	sil_mid.z_index = 10
	props_container.add_child(sil_mid)

	# =====================================================================
	# ANIMATED CAMPFIRE + LIGHTS
	# =====================================================================

	# --- Animated purple campfire ---
	var fire_sprite := AnimatedSprite2D.new()
	fire_sprite.name = "Campfire"
	var fire_sf := SpriteFrames.new()
	if fire_sf.has_animation("default"):
		fire_sf.remove_animation("default")
	fire_sf.add_animation("burn")
	fire_sf.set_animation_speed("burn", 12)
	fire_sf.set_animation_loop("burn", true)
	var fire_tex := load("res://assets/props/Purple Insane 39x38.png") as Texture2D
	for i in range(12):
		var atlas := AtlasTexture.new()
		atlas.atlas = fire_tex
		atlas.region = Rect2(i * 39, 0, 39, 38)
		fire_sf.add_frame("burn", atlas)
	fire_sprite.sprite_frames = fire_sf
	fire_sprite.scale = Vector2(2.4, 2.4)
	fire_sprite.centered = false
	# Bottom edge at ground_y: y = 640 - 38*2.4 = 548.8
	fire_sprite.position = Vector2(camp_x + 440.0, ground_y - 38.0 * 2.4)
	fire_sprite.z_index = 0
	fire_sprite.play("burn")
	props_container.add_child(fire_sprite)

	# --- Purple glow from campfire ---
	campfire_light = PointLight2D.new()
	campfire_light.name = "CampfireGlow"
	campfire_light.color = Color(0.6, 0.2, 0.8, 1.0)
	campfire_light.energy = 1.5
	campfire_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	campfire_light.shadow_enabled = false
	campfire_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	campfire_light.texture_scale = 1.2
	campfire_light.texture = _light_tex
	campfire_light.position = Vector2(39.0 * 2.4 / 2.0, 38.0 * 2.4 / 2.0)
	fire_sprite.add_child(campfire_light)

	# --- Lamppost light — warm incandescent, flicker ---
	# Lamppost prop at camp_x+280, scale 3.0, sprite 18x92 → top at y=364
	lamppost_light = PointLight2D.new()
	lamppost_light.name = "LamppostLight"
	lamppost_light.color = Color(1.0, 0.9, 0.7, 1.0)
	lamppost_light.energy = 0.8
	lamppost_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	lamppost_light.shadow_enabled = false
	lamppost_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lamppost_light.texture_scale = 0.8
	lamppost_light.texture = _light_tex
	# Position at lamp head: x center of lamppost, y near top of sprite
	lamppost_light.position = Vector2(camp_x + 280.0 + 18.0 * 3.0 / 2.0, 380.0)
	props_container.add_child(lamppost_light)


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
