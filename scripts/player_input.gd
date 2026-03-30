class_name PlayerInput


static func register_all_actions() -> void:
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
		"look_down": [],
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
		"look_down": KEY_S,
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
		"look_down": JOY_BUTTON_DPAD_DOWN,
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

	# Left stick down for look_down
	var axis_down := InputEventJoypadMotion.new()
	axis_down.axis = JOY_AXIS_LEFT_Y
	axis_down.axis_value = 1.0
	actions["look_down"].append(axis_down)

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

