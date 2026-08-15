shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.014, 0.14, 0.36, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.02, 0.36, 0.54, 1.0);
uniform vec4 subsurface_color : source_color = vec4(0.05, 0.58, 0.62, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.72, 0.95, 0.9, 1.0);
uniform vec4 foam_color : source_color = vec4(0.94, 0.97, 0.92, 1.0);
uniform float wave_height = 0.5;
uniform float wave_scale = 0.28;
uniform float wave_speed = 0.8;
uniform float color_band_strength = 0.22;
uniform float whitecap_threshold = 0.78;
uniform float normal_strength = 2.0;
// Normal-only detail layer: never displaces vertices, so the CPU mirror in
// OceanWaveField.gd stays valid without knowing about it.
uniform float detail_strength = 0.9;
uniform float glint_roughness : hint_range(0.05, 1.0) = 0.22;
// Foam web (fragment-only): lacy filaments everywhere, denser on crests.
uniform float foam_scale = 0.55;
uniform float foam_coverage : hint_range(0.0, 1.0) = 0.1;
uniform float foam_crest_boost : hint_range(0.0, 1.0) = 0.28;
uniform float foam_opacity : hint_range(0.0, 1.0) = 0.8;
// Slow turquoise mottling so open water isn't one flat blue.
uniform float color_noise_scale = 0.045;
uniform float color_noise_strength : hint_range(0.0, 1.0) = 0.4;
// Driven every frame by the OceanWaveField autoload (not TIME) so ships can
// sample matching wave heights on the CPU. OceanWaveField.gd mirrors the
// wave_value math below; keep the two in sync.
uniform float wave_time = 0.0;

varying float wave_value;
varying vec2 world_xz;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + vec2(34.5));
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	// Rotate each octave so the value-noise cell lattice never lines up
	// across octaves (unrotated it reads as blocky rectangles on the sea).
	const mat2 ROTATE = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float total = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 3; i++) {
		total += value_noise(p) * amplitude;
		p = ROTATE * p * 2.13 + vec2(17.7, 9.2);
		amplitude *= 0.5;
	}
	return total;
}

// Two ridged fbm layers multiplied: bright cellular filaments like the foam
// lace between swells. Scrolls slowly in two directions so it never reads as
// a fixed pattern glued to the sea floor.
float foam_web(vec2 p, float t) {
	float n1 = fbm(p + vec2(t * 0.05, -t * 0.035));
	float n2 = fbm(p * 1.9 + vec2(-t * 0.04, t * 0.055) + vec2(4.7));
	float r1 = 1.0 - abs(n1 * 2.08 - 1.0);
	float r2 = 1.0 - abs(n2 * 2.08 - 1.0);
	return r1 * r2;
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float phase_a = (world_xz.x * wave_scale) + (wave_time * wave_speed);
	float phase_b = (world_xz.y * wave_scale * 1.37) + (wave_time * wave_speed * 0.72);
	float phase_c = ((world_xz.x + world_xz.y) * wave_scale * 0.68) - (wave_time * wave_speed * 0.45);
	wave_value = (sin(phase_a) + cos(phase_b) + sin(phase_c)) / 3.0;
	VERTEX.y += wave_value * wave_height;
}

void fragment() {
	// Analytic slope of the displaced height field, recomputed per pixel
	// (per-vertex normals looked faceted on the 96-subdiv plane), plus a
	// smaller normal-only detail layer that gives the sun a glint band.
	float phase_a = (world_xz.x * wave_scale) + (wave_time * wave_speed);
	float phase_b = (world_xz.y * wave_scale * 1.37) + (wave_time * wave_speed * 0.72);
	float phase_c = ((world_xz.x + world_xz.y) * wave_scale * 0.68) - (wave_time * wave_speed * 0.45);
	float slope_x = (cos(phase_a) * wave_scale + cos(phase_c) * wave_scale * 0.68) * wave_height / 3.0;
	float slope_z = (-sin(phase_b) * wave_scale * 1.37 + cos(phase_c) * wave_scale * 0.68) * wave_height / 3.0;
	float detail_a = (world_xz.x * wave_scale * 3.6) + (wave_time * wave_speed * 1.7);
	float detail_b = ((world_xz.y - world_xz.x * 0.6) * wave_scale * 2.9) - (wave_time * wave_speed * 1.23);
	float detail_amp = wave_height * 0.16 * 0.5;
	float detail_slope_x = (cos(detail_a) * wave_scale * 3.6 - cos(detail_b) * wave_scale * 2.9 * 0.6) * detail_amp;
	float detail_slope_z = (cos(detail_b) * wave_scale * 2.9) * detail_amp;
	// Fade the detail layer out with view distance: up close it reads as
	// sun glints, but at the overworld camera's oblique range it dissolves
	// into a milky wash over the whole sea.
	float view_distance = length(VERTEX);
	float detail_fade = 1.0 - smoothstep(35.0, 85.0, view_distance);
	float detail_mix = detail_strength * detail_fade;
	vec3 world_normal = normalize(vec3(
		-(slope_x * normal_strength + detail_slope_x * detail_mix),
		1.0,
		-(slope_z * normal_strength + detail_slope_z * detail_mix)));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	float crest01 = clamp(wave_value * 0.5 + 0.5, 0.0, 1.0);

	// Foam web sampled at two scales, blended by view distance: fine lace up
	// close (battle camera), chunky patches from the overworld camera so the
	// pattern never shrinks below pixel size into shimmer.
	float far_mix = smoothstep(18.0, 60.0, view_distance);
	vec2 foam_uv = world_xz * foam_scale;
	float web_near = foam_web(foam_uv, wave_time);
	float web_far = foam_web(foam_uv * 0.45 + vec2(7.3), wave_time);
	float web = mix(web_near, web_far, far_mix);
	float coverage = clamp(foam_coverage + crest01 * foam_crest_boost, 0.0, 1.0);
	float cut = mix(0.97, 0.5, coverage);
	float foam_mask = smoothstep(cut, cut + 0.14, web);

	// Whitecaps on the highest crests: edges broken by the web noise and the
	// interior textured by it too, so caps read as froth instead of flat
	// white cloud-blobs.
	float whitecap = smoothstep(whitecap_threshold, whitecap_threshold + 0.16, wave_value + (web - 0.55) * 0.45);
	whitecap *= mix(0.5, 1.0, web);

	float band = floor((wave_value + 1.0) * 3.0) / 3.0;
	vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, clamp((wave_value + 1.0) * 0.5 + band * color_band_strength, 0.0, 1.0));
	// Drifting patches of sunlit turquoise; squared so it stays patchy
	// instead of washing the whole sea brighter.
	float tint = fbm(world_xz * color_noise_scale + vec2(wave_time * 0.012, wave_time * 0.009));
	water_color = mix(water_color, subsurface_color.rgb, clamp(tint * tint * color_noise_strength * (0.55 + 0.45 * crest01), 0.0, 1.0));

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float foam_total = clamp(foam_mask * foam_opacity + whitecap * 0.8, 0.0, 1.0);
	vec3 surface = mix(water_color, highlight_color.rgb, clamp(fresnel * 0.22, 0.0, 1.0));
	ALBEDO = mix(surface, foam_color.rgb, foam_total);
	// Foam is matte; open water keeps the tight sun glints.
	ROUGHNESS = mix(glint_roughness, 0.85, foam_total);
	SPECULAR = mix(0.3, 0.05, foam_total);
}
