class_name PlayerAnimation

const FRAME_W = 192
const FRAME_H = 192


static func create_sprite_frames() -> SpriteFrames:
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

	return sf
