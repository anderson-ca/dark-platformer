shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.7, 0.2, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform float pulse : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	float outline = 0.0;

	outline += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;

	outline = min(outline, 1.0);

	vec4 tex_color = texture(TEXTURE, UV);
	float outline_mask = outline * (1.0 - tex_color.a);

	vec4 glow = outline_color * outline_mask * pulse;
	glow.a *= 0.8;

	COLOR = glow;
}
