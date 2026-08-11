shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.018, 0.18, 0.38, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.02, 0.42, 0.58, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.72, 0.95, 0.9, 1.0);
uniform float wave_height = 0.18;
uniform float wave_scale = 0.16;
uniform float wave_speed = 0.6;
uniform float color_band_strength = 0.22;
uniform float whitecap_threshold = 0.82;

varying float wave_value;

void vertex() {
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float wave_a = sin((world_xz.x * wave_scale) + (TIME * wave_speed));
	float wave_b = cos((world_xz.y * wave_scale * 1.37) + (TIME * wave_speed * 0.72));
	float wave_c = sin(((world_xz.x + world_xz.y) * wave_scale * 0.68) - (TIME * wave_speed * 0.45));
	wave_value = (wave_a + wave_b + wave_c) / 3.0;
	VERTEX.y += wave_value * wave_height;
}

void fragment() {
	float band = floor((wave_value + 1.0) * 3.0) / 3.0;
	vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, clamp((wave_value + 1.0) * 0.5 + band * color_band_strength, 0.0, 1.0));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float whitecap = smoothstep(whitecap_threshold, 1.0, wave_value);
	ALBEDO = mix(water_color, highlight_color.rgb, clamp(fresnel * 0.35 + whitecap * 0.45, 0.0, 1.0));
	ROUGHNESS = 0.42;
	SPECULAR = 0.48;
}
