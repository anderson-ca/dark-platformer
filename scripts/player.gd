extends CharacterBody2D

signal hit_hazard

# Movement
const SPEED = 210.0
const JUMP_VELOCITY = -380.0
const GRAVITY = 1400.0
const MAX_FALL_SPEED = 880.0
const GROUND_ACCELERATION = 1700.0
const AIR_ACCELERATION = 900.0
const GROUND_DRAG = 1900.0
const AIR_DRAG = 180.0

# Coyote time and jump buffer
const COYOTE_TIME = 0.09
const JUMP_BUFFER_TIME = 0.11

# Double jump
const DOUBLE_JUMP_FACTOR = 0.8

# Wall cling + wall jump
const WALL_SLIDE_SPEED = 60.0
const WALL_JUMP_VX = 280.0
const WALL_JUMP_VY = 380.0
const WALL_JUMP_LOCKOUT = 0.2

# Dash
const DASH_SPEED = 400.0
const DASH_DURATION = 0.12
const DASH_COOLDOWN = 0.6

# Sprite frame size (dark sage strips use 192×192 cells)
const FRAME_W = 192
const FRAME_H = 192

# Respawn
var fall_respawn_y: float = 9999.0
var spawn_point: Vector2 = Vector2.ZERO
var checkpoint: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false

# State
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var has_double_jump: bool = true
var wall_jump_lockout_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 0.0
var has_air_dash: bool = true
var facing: float = 1.0
var is_wall_sliding: bool = false
var wall_dir: float = 0.0
var is_attacking: bool = false
var _combo_stage: int = 0  # 0=none, 1=attack1 playing, 2=attack2 playing
var _combo_window: bool = false
var _combo_timer: float = 0.0
const COMBO_WINDOW_TIME := 0.4
var _orb_effect_spawned: bool = false
var _orb_effect_spawned_2: bool = false  # for second orb in full attack
# Attack switching (debug)
var available_attacks: Array = ["None", "Dark Orb"]
var current_attack_index: int = 1
var available_summons: Array = ["None", "Earth Hammer", "Earth Golem", "Earth Trap", "Earth Impale", "Fire Beam", "Petrify", "Tornado", "Earth Burst", "Thunder Burst", "Fire Bite", "Electric Trap", "Dark Tentacle", "Dark Eyes"]
var current_summon_index: int = 1
const SUMMON_CHANNEL_TIME: float = 1.0
var summon_channel_timer: float = 0.0
var is_channeling_summon: bool = false
var summon_triggered_this_channel: bool = false
var summon_global_cooldown: float = 0.0
const SUMMON_GLOBAL_COOLDOWN := 4.0
var _attack_label: Label
var is_shielding: bool = false
var _attack_hitbox: Area2D
var _shield_zone: Area2D  # kept but unused — distance check instead
const SHIELD_ZONE_WIDTH := 10.0
var _shield_phase: String = ""  # "up", "hold", "down"
var is_shockwaving: bool = false
var _shockwave_applied: bool = false
var _original_sprite_material: Material = null
var is_dead: bool = false
var is_invincible: bool = false
var _is_taking_hit: bool = false
var shockwave_cooldown_timer: float = 0.0
const SHOCKWAVE_COOLDOWN := 2.0
const SHOCKWAVE_RADIUS := 120.0
const SHOCKWAVE_KNOCKBACK := 250.0
const SHOCKWAVE_DAMAGE := 2
const SHOCKWAVE_STUN := 0.5
const MAX_HEALTH := 3
var _projectile_cooldown: float = 0.0
const PROJECTILE_COOLDOWN := 0.5
const MAX_PROJECTILES := 3
var current_health: int = MAX_HEALTH

# Raw input tracking
var _key_jump_just: bool = false
var _key_jump_released: bool = false
var _key_dash_just: bool = false
var _key_attack_just: bool = false
var _key_shockwave_just: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var _attack_glow_light: PointLight2D

# Dust animated sprites
var _dust_run: AnimatedSprite2D
var _dust_land: AnimatedSprite2D
var _dust_wall: AnimatedSprite2D
var _dust_dash: AnimatedSprite2D
var _was_on_floor: bool = false
var _was_dashing: bool = false
var _dash_ghost_timer: float = 0.0
const DASH_GHOST_INTERVAL := 0.03


func _register_input_actions() -> void:
	var action_names := ["move_left", "move_right", "jump", "dash", "attack", "shield", "shockwave", "switch_attack", "switch_summon"]

	# Diagnostic: print existing actions before we touch anything
	for action_name in action_names:
		if InputMap.has_action(action_name):
			print("ACTION EXISTS: ", action_name, " events=", InputMap.action_get_events(action_name).size())
			for ev in InputMap.action_get_events(action_name):
				print("  -> ", ev.get_class(), " ", ev)
		else:
			print("ACTION MISSING: ", action_name)

	var actions := {
		"move_left": [],
		"move_right": [],
		"jump": [],
		"dash": [],
		"attack": [],
		"shield": [],
		"shockwave": [],
		"switch_attack": [],
		"switch_summon": [],
	}

	# Keyboard events
	var key_map := {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"dash": KEY_SHIFT,
		"attack": KEY_J,
		"shield": KEY_K,
		"shockwave": KEY_L,
		"switch_attack": KEY_TAB,
		"switch_summon": KEY_QUOTELEFT,
	}
	for action_name in key_map:
		var ev := InputEventKey.new()
		ev.physical_keycode = key_map[action_name]
		actions[action_name].append(ev)

	# Joypad button events
	var btn_map := {
		"jump": JOY_BUTTON_A,
		"attack": JOY_BUTTON_X,
		"shield": JOY_BUTTON_Y,
		"shockwave": JOY_BUTTON_B,
		"switch_attack": JOY_BUTTON_LEFT_SHOULDER,
		"switch_summon": JOY_BUTTON_RIGHT_SHOULDER,
	}
	for action_name in btn_map:
		var ev := InputEventJoypadButton.new()
		ev.button_index = btn_map[action_name]
		actions[action_name].append(ev)

	# D-pad movement + jump
	var dpad_map := {
		"move_left": JOY_BUTTON_DPAD_LEFT,
		"move_right": JOY_BUTTON_DPAD_RIGHT,
		"jump": JOY_BUTTON_DPAD_UP,
	}
	for action_name in dpad_map:
		var ev := InputEventJoypadButton.new()
		ev.button_index = dpad_map[action_name]
		actions[action_name].append(ev)

	# Left stick axes
	var axis_left := InputEventJoypadMotion.new()
	axis_left.axis = JOY_AXIS_LEFT_X
	axis_left.axis_value = -1.0
	actions["move_left"].append(axis_left)

	var axis_right := InputEventJoypadMotion.new()
	axis_right.axis = JOY_AXIS_LEFT_X
	axis_right.axis_value = 1.0
	actions["move_right"].append(axis_right)

	# Dash on right trigger
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 0.5
	actions["dash"].append(rt)

	# Erase and recreate all actions to ensure full control
	for action_name in actions:
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		InputMap.add_action(action_name)
		for ev in actions[action_name]:
			InputMap.action_add_event(action_name, ev)

	# Set deadzone for stick movement
	InputMap.action_set_deadzone("move_left", 0.2)
	InputMap.action_set_deadzone("move_right", 0.2)

	# Verify move actions have all events
	print("move_left events: ", InputMap.action_get_events("move_left").size())
	print("move_right events: ", InputMap.action_get_events("move_right").size())
	for ev in InputMap.action_get_events("move_left"):
		print("  move_left -> ", ev.get_class())
	for ev in InputMap.action_get_events("move_right"):
		print("  move_right -> ", ev.get_class())

	print("INPUT MAP:")
	print("  move_left = A + LeftStick + DPadLeft")
	print("  move_right = D + LeftStick + DPadRight")
	print("  jump = Space + A_Button + DPadUp")
	print("  attack = J + X_Button")
	print("  shield = K + Y_Button")
	print("  shockwave = L + B_Button")
	print("  dash = Shift + RT")
	print("  switch_attack = Tab + L1")
	print("  switch_summon = ` + R1")


func _ready() -> void:
	_register_input_actions()
	add_to_group("player")
	# Player on layer 1, collides with ground (layers 1+3) but NOT enemies (layer 2)
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, true)
	_setup_sprite_frames()
	_setup_dust_sprites()
	_setup_player_light()
	_setup_attack_hitbox()
	_setup_shield_zone()
	_setup_attack_label()
	_setup_attack_glow()
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _setup_sprite_frames() -> void:
	var sf := SpriteFrames.new()

	if sf.has_animation("default"):
		sf.remove_animation("default")

	# [anim_name, file_path, frame_count, fps, loop]
	var P := "res://assets/sprites/player/dark_sage/"
	var anims := [
		["idle",        P + "The Evil Sage-Idle Front.png",  9, 8,  true],
		["run",         P + "The Evil Sage-Run.png",         8, 10, true],
		["jump",        P + "The Evil Sage-Jump.png",        4, 10, false],
		["fall",        P + "The Evil Sage-Fall.png",        4, 8,  true],
		["dash",        P + "The Evil Sage-Dash.png",        4, 14, false],
		["wall_slide",  P + "The Evil Sage-Wall Slide.png",  4, 8,  true],
		["death",       P + "The Evil Sage-Death.png",       8, 8,  false],
		["hit",         P + "The Evil Sage-hit.png",         2, 8,  false],
		["attack1",     P + "The Evil Sage-Orb attack.png",  8, 12, false, 0],
		["attack",      P + "The Evil Sage-Orb attack.png", 16, 12, false, 0],
		["shield_up",   P + "The Evil Sage-Shield up.png",    4, 10, false],
		["shield_hold", P + "The Evil Sage-shield hold.png",  8, 10, true],
		["shield_down", P + "The Evil Sage-shield down.png",  4, 10, false],
		["shockwave",   P + "The Evil Sage-Shockwave.png",   14, 12, false],
		["run_attack",  P + "The Evil Sage-Run-Attack.png",  8, 10, true],
		["jump_attack", P + "The Evil Sage-Jump-Attack.png", 4, 10, false],
	]

	for anim_def in anims:
		var anim_name: String = anim_def[0]
		var file_path: String = anim_def[1]
		var frame_count: int = anim_def[2]
		var fps: float = anim_def[3]
		var looping: bool = anim_def[4]
		var start_frame: int = anim_def[5] if anim_def.size() > 5 else 0

		var texture := load(file_path) as Texture2D

		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, looping)

		for i in range(frame_count):
			var atlas_tex := AtlasTexture.new()
			atlas_tex.atlas = texture
			atlas_tex.region = Rect2((start_frame + i) * FRAME_W, 0, FRAME_W, FRAME_H)
			sf.add_frame(anim_name, atlas_tex)

	animated_sprite.sprite_frames = sf
	for anim_def in anims:
		print("  ", anim_def[0], ": ", anim_def[2], " frames @ ", anim_def[3], " FPS -> ", anim_def[1])
	print("Combo: attack1 (8 frames, single orb) | full attack (16 frames, both orbs) | window=", COMBO_WINDOW_TIME, "s")
	animated_sprite.scale = Vector2(1.5, 1.5)
	# Sage: character at y=107-121 in 192x192 frame, feet at y=121
	# Frame center y=96. Collision bottom = 9px below origin.
	# offset.y = 9/1.5 - (121-96) = 6 - 25 = -19
	animated_sprite.offset = Vector2(0, -19)
	animated_sprite.play("idle")


func _setup_player_light() -> void:
	var light_tex := VFXUtils.create_light_texture(256)

	var light := PointLight2D.new()
	light.name = "PlayerLight"
	light.color = Color(1.0, 0.9, 0.7)
	light.energy = 2.2
	light.texture = light_tex
	light.texture_scale = 1.5
	light.position = Vector2(0, -5)  # roughly center of player body
	light.shadow_enabled = false
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)
	print("PlayerLight: energy=2.2, scale=1.5, color=", light.color)


func _setup_attack_hitbox() -> void:
	_attack_hitbox = Area2D.new()
	_attack_hitbox.name = "AttackHitbox"
	_attack_hitbox.collision_layer = 0
	_attack_hitbox.collision_mask = 4  # detect enemy hitbox layer
	_attack_hitbox.monitoring = false

	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 20)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(20, -5)  # in front of player
	_attack_hitbox.add_child(col)
	add_child(_attack_hitbox)
	_attack_hitbox.area_entered.connect(_on_attack_hit_enemy)


func _setup_shield_zone() -> void:
	_shield_zone = Area2D.new()
	_shield_zone.name = "ShieldZone"
	_shield_zone.collision_layer = 0
	_shield_zone.collision_mask = 2  # detect enemy bodies (layer 2)
	_shield_zone.monitoring = false

	var shape := RectangleShape2D.new()
	shape.size = Vector2(SHIELD_ZONE_WIDTH, 30)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(SHIELD_ZONE_WIDTH / 2.0, -8)  # in front of player
	_shield_zone.add_child(col)
	add_child(_shield_zone)
	print("Shield wall: radius=", SHIELD_ZONE_WIDTH, "px, 360° protection, NO push force, ghoul stops in place")


func _setup_attack_glow() -> void:
	var light_tex := VFXUtils.create_light_texture(64)

	_attack_glow_light = PointLight2D.new()
	_attack_glow_light.name = "AttackGlowLight"
	_attack_glow_light.color = Color(0.6, 0.2, 1.0, 1.0)
	_attack_glow_light.energy = 0.0
	_attack_glow_light.texture = light_tex
	_attack_glow_light.texture_scale = 1.2
	_attack_glow_light.position = Vector2(0, -10)
	_attack_glow_light.shadow_enabled = false
	_attack_glow_light.blend_mode = Light2D.BLEND_MODE_ADD
	_attack_glow_light.enabled = false
	add_child(_attack_glow_light)


func _flash_attack_glow() -> void:
	if not _attack_glow_light:
		return
	_attack_glow_light.enabled = true
	_attack_glow_light.energy = 2.5
	var tween := create_tween()
	tween.tween_property(_attack_glow_light, "energy", 0.0, 0.25)
	tween.tween_callback(func(): _attack_glow_light.enabled = false)


func _setup_attack_label() -> void:
	_attack_label = Label.new()
	_attack_label.name = "AttackLabel"
	_attack_label.add_theme_font_size_override("font_size", 11)
	_attack_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	_attack_label.position = Vector2(12, 70)
	# Add to HUD CanvasLayer so it stays fixed on screen
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud:
		hud.add_child(_attack_label)
	else:
		add_child(_attack_label)
	_update_debug_label()
	print("Skill switcher: Tab=attack, `=summon")


func _update_debug_label() -> void:
	if _attack_label:
		var txt: String = "J: " + available_attacks[current_attack_index] + " | K: " + available_summons[current_summon_index]
		if summon_global_cooldown > 0.0:
			txt += " (CD: " + str(snapped(summon_global_cooldown, 0.1)) + "s)"
		_attack_label.text = txt


func _repel_enemies_from_shield() -> void:
	# Hard wall: only block enemies on the side the player is facing
	var shield_edge_x: float = global_position.x + facing * SHIELD_ZONE_WIDTH
	print("Shield wall: facing=", facing, " edge_x=", shield_edge_x, " player_x=", global_position.x)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_x: float = enemy.global_position.x
		# Only affect enemies on the side we're facing
		var enemy_side: float = sign(enemy_x - global_position.x)
		if enemy_side != facing and enemy_side != 0.0:
			continue  # enemy is behind the shield
		# Check if enemy is closer than shield edge
		if facing > 0 and enemy_x < shield_edge_x:
			enemy.global_position.x = shield_edge_x
			if enemy.velocity.x < 0.0:  # moving toward player
				enemy.velocity.x = 0.0
		elif facing < 0 and enemy_x > shield_edge_x:
			enemy.global_position.x = shield_edge_x
			if enemy.velocity.x > 0.0:  # moving toward player
				enemy.velocity.x = 0.0


func _spawn_electric_hit(pos: Vector2) -> void:
	VFXUtils.spawn_sprite_effect(get_parent(), "res://assets/effects/combat/hit/Electric Hit 4.png", 9, 82, 65, pos + Vector2(0, -12), "electric", 14.0, Vector2(0.4, 0.4))


func _apply_shockwave_effect() -> void:
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dx: float = abs(enemy.global_position.x - global_position.x)
		var dy: float = abs(enemy.global_position.y - global_position.y)
		if dx < SHOCKWAVE_RADIUS and dy < 50:
			hit_count += 1
			# Knockback away from player
			var kb_dir: float = sign(enemy.global_position.x - global_position.x)
			if kb_dir == 0.0:
				kb_dir = facing
			# Deal 2 hits of damage
			if enemy.has_method("take_damage"):
				for i in range(SHOCKWAVE_DAMAGE):
					enemy.take_damage(global_position)
			# Knockback + stun AFTER damage (stun overrides HIT state)
			enemy.velocity.x = kb_dir * SHOCKWAVE_KNOCKBACK
			enemy.velocity.y = -120.0
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(SHOCKWAVE_STUN)
			_spawn_electric_hit(enemy.global_position)
	print("Shockwave: radius=", SHOCKWAVE_RADIUS, "px knockback=", SHOCKWAVE_KNOCKBACK, " stun=", SHOCKWAVE_STUN, "s damage=", SHOCKWAVE_DAMAGE, " hit=", hit_count, " enemies")


func _on_attack_hit_enemy(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy.has_method("take_damage"):
		enemy.take_damage(global_position)


func take_damage(from_position: Vector2) -> void:
	if is_dead or is_invincible:
		return
	if is_shielding:
		print("Shield BLOCKED attack!")
		_spawn_shield_block_effect()
		var ghouls := get_tree().get_nodes_in_group("enemies")
		for enemy in ghouls:
			if enemy.has_method("take_knockback"):
				var dist := global_position.distance_to(enemy.global_position)
				if dist < 60.0:
					enemy.take_knockback(global_position)
		return
	current_health -= 1
	print("Player hit! health=", current_health, "/", MAX_HEALTH)
	if current_health <= 0:
		_play_death()
	else:
		_play_hit(from_position)


func _spawn_shield_block_effect() -> void:
	VFXUtils.spawn_sprite_effect(get_parent(), "res://assets/effects/combat/hit/Blood Hit 1.png", 7, 82, 65, global_position + Vector2(facing * 15, -10), "shield_block")


func _spawn_double_jump_burst() -> void:
	var offsets := [
		Vector2(0, 5),
		Vector2(0, 15),
		Vector2(0, 25)
	]
	for offset in offsets:
		var ghost := animated_sprite.duplicate() as AnimatedSprite2D
		get_parent().add_child(ghost)
		ghost.global_position = global_position + offset
		ghost.animation = animated_sprite.animation
		ghost.frame = animated_sprite.frame
		ghost.flip_h = animated_sprite.flip_h
		ghost.pause()
		ghost.modulate = Color(0.8, 0.3, 1.0, 0.5)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "global_position", ghost.global_position + Vector2(0, 15), 0.25)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
		tween.set_parallel(false)
		tween.tween_callback(ghost.queue_free)


func _spawn_dash_ghost() -> void:
	var ghost := animated_sprite.duplicate() as AnimatedSprite2D
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	ghost.animation = animated_sprite.animation
	ghost.frame = animated_sprite.frame
	ghost.flip_h = animated_sprite.flip_h
	ghost.pause()
	ghost.modulate = Color(0.8, 0.3, 1.0, 0.7)
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


func _spawn_projectile() -> void:
	var attack_name: String = available_attacks[current_attack_index]
	if attack_name == "None":
		return

	var projectile_scene: PackedScene
	match attack_name:
		"Dark Orb":
			projectile_scene = preload("res://scenes/projectiles/orb_projectile.tscn")
		_:
			return

	if get_tree().get_nodes_in_group("projectiles").size() >= MAX_PROJECTILES:
		print("Max projectiles on screen")
		return

	var projectile := projectile_scene.instantiate()
	var dir: int = -1 if animated_sprite.flip_h else 1
	projectile.direction = dir
	projectile.global_position = global_position + Vector2(dir * 30, -5)
	projectile.muzzle_spawn_position = global_position + Vector2(dir * 16, 0)
	projectile.add_to_group("projectiles")
	get_parent().add_child(projectile)
	print("Spawned projectile: ", attack_name, " at: ", projectile.global_position)


func _spawn_summon() -> void:
	var summon_name: String = available_summons[current_summon_index]
	if summon_name == "None":
		return

	var summon_scene: PackedScene
	match summon_name:
		"Earth Hammer":
			summon_scene = preload("res://scenes/summons/earth_hammer_summon.tscn")
		"Earth Golem":
			summon_scene = preload("res://scenes/summons/earth_golem_summon.tscn")
		"Earth Trap":
			summon_scene = preload("res://scenes/summons/earth_trap_summon.tscn")
		"Earth Impale":
			summon_scene = preload("res://scenes/summons/earth_impale_summon.tscn")
		"Fire Beam":
			summon_scene = preload("res://scenes/summons/fire_beam_summon.tscn")
		"Petrify":
			summon_scene = preload("res://scenes/summons/petrify_summon.tscn")
		"Tornado":
			summon_scene = preload("res://scenes/summons/tornado_summon.tscn")
		"Earth Burst":
			summon_scene = preload("res://scenes/summons/earth_burst_summon.tscn")
		"Thunder Burst":
			summon_scene = preload("res://scenes/summons/thunder_burst_summon.tscn")
		"Fire Bite":
			summon_scene = preload("res://scenes/summons/fire_bite_summon.tscn")
		"Electric Trap":
			summon_scene = preload("res://scenes/summons/electric_trap_summon.tscn")
		"Dark Tentacle":
			summon_scene = preload("res://scenes/summons/dark_tentacle_summon.tscn")
		"Dark Eyes":
			summon_scene = preload("res://scenes/summons/dark_eyes_summon.tscn")
		_:
			return

	var summon := summon_scene.instantiate()
	var dir: int = -1 if animated_sprite.flip_h else 1
	summon.direction = dir
	var offset: Vector2 = summon.spawn_offset
	offset.x *= dir
	summon.global_position = global_position + offset
	get_parent().add_child(summon)
	print("Spawned summon: ", summon_name)


func _spawn_blood_effect() -> void:
	VFXUtils.spawn_sprite_effect(get_parent(), "res://assets/effects/combat/hit/Blood hit 3.png", 9, 82, 65, global_position + Vector2(0, -10), "blood")


func _play_hit(from_position: Vector2) -> void:
	_spawn_blood_effect()
	_is_taking_hit = true
	is_invincible = true
	is_attacking = false
	_combo_stage = 0
	_combo_window = false
	is_shielding = false
	_shield_phase = ""
	_shield_zone.monitoring = false
	is_shockwaving = false
	_attack_hitbox.monitoring = false

	# Knockback away from damage source
	var kb_dir: float = sign(global_position.x - from_position.x)
	if kb_dir == 0.0:
		kb_dir = 1.0
	velocity.x = kb_dir * 120.0
	velocity.y = -80.0

	animated_sprite.play("hit")
	print("Player hit animation: 2 frames @ 8 FPS, invincible for 0.5s")

	# Wait for hit animation
	await get_tree().create_timer(0.25).timeout
	_is_taking_hit = false
	if is_dead:
		return

	# Blink for remaining invincibility
	var blink_end := 0.5  # total blink time after hit anim
	var blink_elapsed := 0.0
	while blink_elapsed < blink_end:
		animated_sprite.visible = not animated_sprite.visible
		await get_tree().create_timer(0.06).timeout
		blink_elapsed += 0.06
		if is_dead:
			animated_sprite.visible = true
			return

	animated_sprite.visible = true
	is_invincible = false


func _play_death() -> void:
	is_dead = true
	is_attacking = false
	_combo_stage = 0
	_combo_window = false
	is_shielding = false
	is_shockwaving = false
	_attack_hitbox.monitoring = false
	_shield_zone.monitoring = false
	velocity = Vector2.ZERO
	animated_sprite.play("death")
	print("Player death: 8 frames @ 8 FPS, waiting 1.5s before respawn")
	await get_tree().create_timer(1.5).timeout
	is_dead = false
	hit_hazard.emit()


func _setup_dust_sprites() -> void:
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
		add_child(sprite)
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


func _on_land_dust_finished() -> void:
	_dust_land.visible = false


func _on_dash_dust_finished() -> void:
	_dust_dash.visible = false


func _input(event: InputEvent) -> void:
	# Mouse buttons — attack / shield / shockwave (kept for mouse support)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_key_attack_just = true
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			_key_shockwave_just = true
		return

	if event.is_action_pressed("attack"):
		_key_attack_just = true
	if event.is_action_pressed("jump"):
		_key_jump_just = true
	if event.is_action_released("jump"):
		_key_jump_released = true
	if event.is_action_pressed("dash"):
		_key_dash_just = true
	if event.is_action_pressed("shockwave"):
		_key_shockwave_just = true
	if event.is_action_pressed("switch_attack"):
		current_attack_index = (current_attack_index + 1) % available_attacks.size()
		_update_debug_label()
		print("Switched to attack: ", available_attacks[current_attack_index], " (device: ", event.device, ")")
	if event.is_action_pressed("switch_summon"):
		current_summon_index = (current_summon_index + 1) % available_summons.size()
		_update_debug_label()
		print("Switched to summon: ", available_summons[current_summon_index], " (device: ", event.device, ")")


func _on_animation_finished() -> void:
	if animated_sprite.animation == "attack1":
		_attack_hitbox.monitoring = false
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# Single tap finished — open combo window for double tap
		_combo_window = true
		_combo_timer = COMBO_WINDOW_TIME
		is_attacking = false  # brief movement window between taps
	elif animated_sprite.animation == "attack":
		# Full combo attack finished
		is_attacking = false
		_combo_stage = 0
		_combo_window = false
		_attack_hitbox.monitoring = false
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif animated_sprite.animation == "shield_up":
		_shield_phase = "hold"
		animated_sprite.play("shield_hold")
	elif animated_sprite.animation == "shield_down":
		is_shielding = false
		_shield_phase = ""
	elif animated_sprite.animation == "shockwave":
		is_shockwaving = false
		is_invincible = false
		animated_sprite.material = _original_sprite_material
		_original_sprite_material = null


func reset_abilities() -> void:
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	has_double_jump = true
	wall_jump_lockout_timer = 0.0
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	has_air_dash = true
	is_attacking = false
	_combo_stage = 0
	_combo_window = false
	_combo_timer = 0.0
	is_shielding = false
	_shield_phase = ""
	is_shockwaving = false
	is_dead = false
	is_invincible = false
	_is_taking_hit = false
	current_health = MAX_HEALTH
	shockwave_cooldown_timer = 0.0
	velocity = Vector2.ZERO
	animated_sprite.visible = true


func respawn() -> void:
	if has_checkpoint:
		global_position = checkpoint
	else:
		global_position = spawn_point
	reset_abilities()


func set_spawn(pos: Vector2) -> void:
	spawn_point = pos
	has_checkpoint = false
	checkpoint = Vector2.ZERO


func activate_checkpoint(pos: Vector2) -> void:
	checkpoint = pos
	has_checkpoint = true


func _physics_process(delta: float) -> void:
	if is_dead or _is_taking_hit:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DRAG * delta)
		move_and_slide()
		return

	# Consume one-shot input flags
	var jump_just_pressed := _key_jump_just
	var jump_just_released := _key_jump_released
	var dash_just_pressed := _key_dash_just
	var attack_just_pressed := _key_attack_just
	var shield_held := Input.is_action_pressed("shield") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var shockwave_just_pressed := _key_shockwave_just
	_key_jump_just = false
	_key_jump_released = false
	_key_dash_just = false
	_key_attack_just = false
	_key_shockwave_just = false

	# Timers
	shockwave_cooldown_timer = max(shockwave_cooldown_timer - delta, 0.0)
	_projectile_cooldown = max(_projectile_cooldown - delta, 0.0)
	var _prev_summon_cd := summon_global_cooldown
	summon_global_cooldown = max(summon_global_cooldown - delta, 0.0)
	if _prev_summon_cd > 0.0 and summon_global_cooldown <= 0.0:
		print("Summon cooldown expired — ready")
	if _combo_window:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_window = false
			_combo_stage = 0

	# Fall respawn check
	if global_position.y > fall_respawn_y:
		hit_hazard.emit()
		return

	# --- Shockwave (highest priority except death) ---
	if shockwave_just_pressed and is_on_floor() and not is_shockwaving and shockwave_cooldown_timer <= 0.0:
		is_shockwaving = true
		_shockwave_applied = false
		is_invincible = true
		is_attacking = false
		is_shielding = false
		_shield_phase = ""
		_shield_zone.monitoring = false
		shockwave_cooldown_timer = SHOCKWAVE_COOLDOWN
		velocity.x = 0.0
		animated_sprite.play("shockwave")
		# Apply red outline immediately so buildup frames are visible
		_original_sprite_material = animated_sprite.material
		var _sw_shader := Shader.new()
		_sw_shader.code = """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0.8, 0.1, 0.1, 0.6);
uniform float outline_width : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a < 0.1) {
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(outline_width * TEXTURE_PIXEL_SIZE.x, 0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(outline_width * TEXTURE_PIXEL_SIZE.x, 0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0, outline_width * TEXTURE_PIXEL_SIZE.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0, outline_width * TEXTURE_PIXEL_SIZE.y)).a);
		if (a > 0.1) {
			col = outline_color;
		}
	}
	COLOR = col;
}
"""
		var _sw_mat := ShaderMaterial.new()
		_sw_mat.shader = _sw_shader
		_sw_mat.set_shader_parameter("outline_color", Color(0.8, 0.1, 0.1, 0.6))
		_sw_mat.set_shader_parameter("outline_width", 1.0)
		animated_sprite.material = _sw_mat
		print("Shockwave outline: applied at frame 0")

	if is_shockwaving:
		# Apply effect at frame 6 (when blast visual appears)
		if not _shockwave_applied and animated_sprite.frame >= 6:
			_shockwave_applied = true
			_apply_shockwave_effect()
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DRAG * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
		move_and_slide()
		_was_on_floor = is_on_floor()
		return

	# --- Shield + Summon channeling ---
	if shield_held and is_on_floor() and not is_attacking and dash_timer <= 0.0:
		if not is_shielding:
			is_shielding = true
			is_channeling_summon = true
			summon_channel_timer = 0.0
			summon_triggered_this_channel = false
			_shield_phase = "up"
			animated_sprite.play("shield_up")
			_shield_zone.scale.x = facing
			_shield_zone.monitoring = true
			print("Started channeling summon...")
		elif is_channeling_summon and not summon_triggered_this_channel:
			if summon_global_cooldown > 0.0:
				print("Summon cooldown: ", snapped(summon_global_cooldown, 0.1), "s remaining")
			else:
				summon_channel_timer += delta
				if summon_channel_timer >= SUMMON_CHANNEL_TIME:
					_spawn_summon()
					summon_triggered_this_channel = true
					summon_global_cooldown = SUMMON_GLOBAL_COOLDOWN
					print("SUMMON COMPLETE! Cooldown: ", SUMMON_GLOBAL_COOLDOWN, "s")
	elif is_shielding and not shield_held:
		if not summon_triggered_this_channel:
			print("Channel cancelled - released too early")
		_shield_phase = "down"
		animated_sprite.play("shield_down")
		_shield_zone.monitoring = false
		is_channeling_summon = false
		summon_channel_timer = 0.0

	if is_shielding:
		# Repel enemies each frame
		_repel_enemies_from_shield()
		# No movement while shielding — stationary
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
		move_and_slide()
		_was_on_floor = is_on_floor()
		animated_sprite.flip_h = facing < 0.0
		animated_sprite.position.x = 0.0
		return

	# --- Attack / Combo (PATH A — standing still on ground) ---
	var _standing_attack_fired := false
	var is_moving_input := Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
	if attack_just_pressed and is_on_floor() and not is_moving_input and dash_timer <= 0.0:
		if _combo_window and _combo_stage == 1:
			# Double tap: play full attack (both orbs)
			is_attacking = true
			_combo_stage = 2
			_combo_window = false
			_orb_effect_spawned = false
			_orb_effect_spawned_2 = false
			velocity.x = 0.0
			animated_sprite.play("attack")
			animated_sprite.modulate = Color(0.85, 0.7, 1.0, 1.0)
			_flash_attack_glow()
			_attack_hitbox.scale.x = facing
			_attack_hitbox.monitoring = false  # enabled on impact frames
			_standing_attack_fired = true
			print("PATH A: standing attack (combo)")
		elif not is_attacking and _combo_stage == 0:
			# Single tap: quick attack (first orb only)
			is_attacking = true
			_combo_stage = 1
			_combo_window = false
			_orb_effect_spawned = false
			velocity.x = 0.0
			animated_sprite.play("attack1")
			animated_sprite.modulate = Color(0.85, 0.7, 1.0, 1.0)
			_flash_attack_glow()
			_attack_hitbox.scale.x = facing
			_attack_hitbox.monitoring = false  # enabled on impact frames
			_standing_attack_fired = true
			print("PATH A: standing attack")

	# --- Moving/Air Projectile Attack (PATH B) ---
	if attack_just_pressed and not _standing_attack_fired and dash_timer <= 0.0 and not is_attacking and _projectile_cooldown <= 0.0:
		_spawn_projectile()
		_flash_attack_glow()
		_projectile_cooldown = PROJECTILE_COOLDOWN
		# Brief backward recoil (~14% slowdown at full speed)
		velocity.x -= facing * 30.0
		if is_on_floor():
			print("PATH B: moving/air attack (ground)")
		else:
			print("PATH B: moving/air attack (air)")

	if is_attacking:
		# Dash cancel — interrupt attack with dash
		if dash_just_pressed and dash_cooldown_timer <= 0.0:
			if is_on_floor() or has_air_dash:
				is_attacking = false
				_combo_stage = 0
				_combo_window = false
				_attack_hitbox.monitoring = false
				dash_timer = DASH_DURATION
				dash_cooldown_timer = DASH_COOLDOWN
				dash_direction = facing
				is_invincible = true
				if not is_on_floor():
					has_air_dash = false
				velocity.x = dash_direction * DASH_SPEED
				if not is_on_floor():
					velocity.y = min(velocity.y, 30.0)
				animated_sprite.modulate = Color(0.9, 0.6, 1.0, 1.0)
				print("Dash cancelled attack! (i-frames active)")
				move_and_slide()
				_was_on_floor = is_on_floor()
				_update_animation()
				_update_dust(false)
				return
		# Frame-synced hitbox + VFX: only active during orb impact frames
		var f := animated_sprite.frame
		if _combo_stage == 1:
			# attack1 (8 frames): impact at frames 4-6
			_attack_hitbox.monitoring = (f >= 4 and f <= 6)
			if f == 4 and not _orb_effect_spawned:
				_orb_effect_spawned = true
				_spawn_projectile()
		elif _combo_stage == 2:
			# full attack (16 frames): first orb 4-6, second orb 12-14
			_attack_hitbox.monitoring = (f >= 4 and f <= 6) or (f >= 12 and f <= 14)
			if f == 4 and not _orb_effect_spawned:
				_orb_effect_spawned = true
				_spawn_projectile()
			if f == 12 and not _orb_effect_spawned_2:
				_orb_effect_spawned_2 = true
				_spawn_projectile()
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DRAG * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
			velocity.y = min(velocity.y, MAX_FALL_SPEED)
		move_and_slide()
		_was_on_floor = is_on_floor()
		return

	var on_floor := is_on_floor()
	var on_wall := is_on_wall()
	var input_dir := 0.0
	if Input.is_action_pressed("move_right"):
		input_dir += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir -= 1.0
	var wall_normal := get_wall_normal() if on_wall else Vector2.ZERO

	# --- Timers ---
	coyote_timer = max(coyote_timer - delta, 0.0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	wall_jump_lockout_timer = max(wall_jump_lockout_timer - delta, 0.0)
	dash_timer = max(dash_timer - delta, 0.0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)

	# --- Landing resets ---
	if on_floor:
		coyote_timer = COYOTE_TIME
		has_double_jump = true
		has_air_dash = true

	# --- Dashing ---
	if dash_timer > 0.0:
		_dash_ghost_timer += delta
		if _dash_ghost_timer >= DASH_GHOST_INTERVAL:
			_spawn_dash_ghost()
			_dash_ghost_timer = 0.0
		velocity.x = dash_direction * DASH_SPEED
		if not on_floor:
			velocity.y = min(velocity.y, 30.0)
		move_and_slide()
		_was_on_floor = is_on_floor()
		_update_animation()
		_update_dust(false)
		return

	# Dash just ended — remove i-frames and purple tint (unless in hit recovery)
	if _was_dashing and not _is_taking_hit:
		is_invincible = false
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		print("DASH ENDED: invincible=false")

	# --- Dash input ---
	if dash_just_pressed and dash_cooldown_timer <= 0.0:
		if on_floor or has_air_dash:
			dash_timer = DASH_DURATION
			dash_cooldown_timer = DASH_COOLDOWN
			dash_direction = facing
			is_invincible = true
			_dash_ghost_timer = 0.0
			animated_sprite.modulate = Color(0.9, 0.6, 1.0, 1.0)
			print("DASH: invincible=true")
			if not on_floor:
				has_air_dash = false
			velocity.x = dash_direction * DASH_SPEED
			if not on_floor:
				velocity.y = min(velocity.y, 30.0)
			move_and_slide()
			_was_on_floor = is_on_floor()
			_update_animation()
			_update_dust(false)
			return

	# --- Gravity ---
	if not on_floor:
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)

	# --- Wall slide ---
	is_wall_sliding = false
	wall_dir = 0.0
	if on_wall and not on_floor and velocity.y > 0.0:
		if (input_dir > 0.0 and wall_normal.x < 0.0) or (input_dir < 0.0 and wall_normal.x > 0.0):
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)
			has_double_jump = true
			is_wall_sliding = true
			wall_dir = -wall_normal.x

	# --- Jump buffer ---
	if jump_just_pressed:
		jump_buffer_timer = JUMP_BUFFER_TIME

	# --- Jump logic ---
	var can_coyote_jump := coyote_timer > 0.0
	var can_wall_jump := on_wall and not on_floor

	if jump_buffer_timer > 0.0:
		if can_coyote_jump:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
		elif can_wall_jump:
			velocity.y = -WALL_JUMP_VY
			velocity.x = wall_normal.x * WALL_JUMP_VX
			wall_jump_lockout_timer = WALL_JUMP_LOCKOUT
			jump_buffer_timer = 0.0
			has_double_jump = true
			coyote_timer = 0.0
		elif has_double_jump and not on_floor:
			velocity.y = JUMP_VELOCITY * DOUBLE_JUMP_FACTOR
			has_double_jump = false
			jump_buffer_timer = 0.0
			_spawn_double_jump_burst()

	# --- Jump buffer on landing ---
	if on_floor and jump_buffer_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0

	# --- Variable jump height ---
	if jump_just_released and velocity.y < 0.0:
		velocity.y *= 0.5

	# --- Horizontal movement ---
	if wall_jump_lockout_timer <= 0.0:
		var accel := GROUND_ACCELERATION if on_floor else AIR_ACCELERATION
		var drag := GROUND_DRAG if on_floor else AIR_DRAG

		if input_dir != 0.0:
			velocity.x = move_toward(velocity.x, input_dir * SPEED, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, drag * delta)

	# --- Facing direction ---
	if input_dir != 0.0:
		facing = input_dir

	move_and_slide()

	# --- Landing detection for dust burst ---
	var landed := is_on_floor() and not _was_on_floor
	_was_on_floor = is_on_floor()

	_update_animation()
	_update_dust(landed)


func _update_animation() -> void:
	# Flip based on facing
	if is_wall_sliding:
		animated_sprite.flip_h = wall_dir > 0
		# Nudge sprite toward wall to close visual gap (6px)
		animated_sprite.position.x = wall_dir * 6.0
	else:
		animated_sprite.flip_h = facing < 0.0
		animated_sprite.position.x = 0.0

	# Don't override animation during combo window or active attack
	if is_attacking:
		return
	if _combo_window and _combo_stage >= 1:
		return

	# Pick animation
	var anim := "idle"
	if dash_timer > 0.0:
		anim = "dash"
	elif is_wall_sliding:
		anim = "wall_slide"
	elif _projectile_cooldown > 0.0:
		# Recently fired a moving/air projectile — show casting animation
		if not is_on_floor():
			anim = "jump_attack"
		elif abs(velocity.x) > 10:
			anim = "run_attack"
		else:
			anim = "idle"
	elif not is_on_floor():
		if velocity.y < -40:
			anim = "jump"
		else:
			anim = "fall"
	elif abs(velocity.x) > 30:
		anim = "run"

	if animated_sprite.animation != anim or not animated_sprite.is_playing():
		print("Animation: ", anim)
		animated_sprite.play(anim)


func _update_dust(landed: bool) -> void:
	var on_floor := is_on_floor()
	var feet_y := 9.0

	# --- Run dust: play when running on ground, not dashing ---
	var is_running: bool = on_floor and abs(velocity.x) > 30 and dash_timer <= 0.0
	if is_running:
		_dust_run.flip_h = velocity.x > 0.0
		_dust_run.position = Vector2(-sign(velocity.x) * 4.0, feet_y)
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
		var wn := get_wall_normal()
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
