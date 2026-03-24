shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.6, 0.2, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	if (col.a < 0.5) {
		float outline = 0.0;
		vec2 size = TEXTURE_PIXEL_SIZE * outline_width;

		outline += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
		outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;

		if (outline > 0.0) {
			col = outline_color;
		}
	}

	COLOR = col;
}
