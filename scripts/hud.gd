extends CanvasLayer

var room_label: Label
var hint_label: Label
var respawn_label: Label
var health_label: Label
var flash_rect: ColorRect
var _flash_timer: float = 0.0
var _respawn_msg_timer: float = 0.0
var _player: CharacterBody2D = null


func _ready() -> void:
	layer = 10

	room_label = Label.new()
	room_label.position = Vector2(12, 8)
	room_label.add_theme_font_size_override("font_size", 16)
	room_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	add_child(room_label)

	hint_label = Label.new()
	hint_label.position = Vector2(12, 30)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	add_child(hint_label)

	respawn_label = Label.new()
	respawn_label.position = Vector2(12, 420)
	respawn_label.add_theme_font_size_override("font_size", 12)
	respawn_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	respawn_label.visible = false
	add_child(respawn_label)

	health_label = Label.new()
	health_label.position = Vector2(12, 50)
	health_label.add_theme_font_size_override("font_size", 14)
	health_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	health_label.text = "HP: 3 / 3"
	add_child(health_label)

	flash_rect = ColorRect.new()
	flash_rect.position = Vector2.ZERO
	flash_rect.size = Vector2(800, 450)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)


func set_room_name(room_name: String, index: int) -> void:
	room_label.text = "Room %d — %s" % [index + 1, room_name]


func set_hints(hints: Array) -> void:
	var text := ""
	for h in hints:
		if text != "":
			text += "\n"
		text += str(h)
	hint_label.text = text


func set_player(p: CharacterBody2D) -> void:
	_player = p


func update_health(current: int, max_hp: int) -> void:
	health_label.text = "HP: %d / %d" % [current, max_hp]


func flash_respawn() -> void:
	_flash_timer = 0.12
	flash_rect.color = Color(1, 1, 1, 0.7)
	respawn_label.text = "Fell out of room. Respawned."
	respawn_label.visible = true
	_respawn_msg_timer = 2.0


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		var alpha := clampf(_flash_timer / 0.12, 0.0, 1.0) * 0.7
		flash_rect.color = Color(1, 1, 1, alpha)
		if _flash_timer <= 0.0:
			flash_rect.color = Color(1, 1, 1, 0)

	if _respawn_msg_timer > 0.0:
		_respawn_msg_timer -= delta
		if _respawn_msg_timer <= 0.0:
			respawn_label.visible = false

	if _player and _player.has_method("get") and "current_health" in _player:
		health_label.text = "HP: %d / %d" % [_player.current_health, _player.MAX_HEALTH]
