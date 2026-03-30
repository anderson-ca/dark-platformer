shader_type canvas_item;

uniform vec3 target_color : source_color = vec3(0.196, 0.184, 0.157);
uniform float blend_amount : hint_range(0.0, 1.0) = 0.6;
uniform float darken_amount : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = vec3(lum) * 0.7 + tex_color.rgb * 0.3;
	vec3 tinted = mix(desat, target_color * (lum + 0.3), blend_amount);
	tinted *= (1.0 - darken_amount);
	COLOR = vec4(tinted, tex_color.a);
}
