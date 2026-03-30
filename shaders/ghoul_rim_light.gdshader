shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(0.28, 0.07, 0.42, 0.4);
uniform float rim_width : hint_range(0.0, 5.0) = 0.8;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Recolor red pixels to purple (eyes and blood effects)
	// Red pixels: r > 0.3, r > g * 2.0, r > b * 2.0
	float is_red = step(0.3, tex_color.r) * step(tex_color.g * 2.0, tex_color.r) * step(tex_color.b * 2.0, tex_color.r) * tex_color.a;
	vec3 purpled = vec3(tex_color.r * 0.5, tex_color.g * 0.3, tex_color.r * 0.8 + 0.1);
	tex_color.rgb = mix(tex_color.rgb, purpled, is_red);

	// Rim light edge detection
	vec2 size = TEXTURE_PIXEL_SIZE * rim_width;
	float neighbor = 0.0;

	neighbor += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
	neighbor += texture(TEXTURE, UV + vec2(size.x, 0)).a;
	neighbor += texture(TEXTURE, UV + vec2(0, -size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(0, size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	neighbor += texture(TEXTURE, UV + vec2(size.x, size.y)).a;

	neighbor = min(neighbor, 1.0);

	float rim_mask = neighbor * (1.0 - tex_color.a);
	vec4 rim = rim_color * rim_mask;
	COLOR = mix(rim, tex_color, tex_color.a);
}
