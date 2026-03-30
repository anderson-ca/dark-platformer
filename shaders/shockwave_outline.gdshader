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
