shader_type canvas_item;

uniform vec3 stone_color : source_color = vec3(0.196, 0.184, 0.157);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gray = vec3(lum);
	vec3 stoned = mix(gray, stone_color, 0.7);
	stoned *= 0.6;
	COLOR = vec4(stoned, tex.a);
}
