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
// Gerstner swell pair: long wind-aligned waves whose horizontal displacement
// pinches crests and flattens troughs. The second component is derived from
// these knobs by fixed multipliers (SWELL2_* below) so one set tunes both.
// The full vertex math is mirrored on the CPU in OceanWaveField.gd — any
// change here MUST be made there too or ships float off the rendered sea.
uniform vec2 swell_direction = vec2(0.42, -0.91);
uniform float swell_wavelength = 38.0;
uniform float swell_amplitude = 0.6;
// Total crest pinch across both components; keep below 1.0 or crest loops.
uniform float swell_steepness : hint_range(0.0, 0.95) = 0.6;
uniform float swell_speed = 3.2;
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
varying float crest_pinch;

// Fixed relation of the derived second swell to the primary.
const float SWELL2_ROTATE_COS = 0.83;
const float SWELL2_ROTATE_SIN = 0.56;
const float SWELL2_WAVELENGTH = 0.6;
const float SWELL2_AMPLITUDE = 0.55;
const float SWELL2_SPEED = 0.8;
const float SWELL2_PHASE = 2.1;

// One Gerstner component. qa is the horizontal sway in world units
// (Q * amplitude in the classic formulation); qa * k is its crest pinch.
vec3 gerstner_offset(vec2 xz, float t, vec2 d, float k, float a, float qa, float c, float phase0) {
	float ph = k * dot(d, xz) - k * c * t + phase0;
	return vec3(d.x * qa * cos(ph), a * sin(ph), d.y * qa * cos(ph));
}

float gerstner_pinch(vec2 xz, float t, vec2 d, float k, float qa, float c, float phase0) {
	float ph = k * dot(d, xz) - k * c * t + phase0;
	return qa * k * sin(ph);
}

vec2 gerstner_slope(vec2 xz, float t, vec2 d, float k, float a, float c, float phase0) {
	float ph = k * dot(d, xz) - k * c * t + phase0;
	return d * k * a * cos(ph);
}

vec2 swell2_direction() {
	vec2 d = normalize(swell_direction);
	return vec2(SWELL2_ROTATE_COS * d.x - SWELL2_ROTATE_SIN * d.y,
		SWELL2_ROTATE_SIN * d.x + SWELL2_ROTATE_COS * d.y);
}

#include "res://game/shaders/water_noise.gdshaderinc"

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
	float chop = (sin(phase_a) + cos(phase_b) + sin(phase_c)) / 3.0;

	vec2 d1 = normalize(swell_direction);
	vec2 d2 = swell2_direction();
	float k1 = TAU / swell_wavelength;
	float k2 = TAU / (swell_wavelength * SWELL2_WAVELENGTH);
	float a1 = swell_amplitude;
	float a2 = swell_amplitude * SWELL2_AMPLITUDE;
	// Split the steepness budget 60/40; qa * k sums to swell_steepness.
	float qa1 = swell_steepness * 0.6 / k1;
	float qa2 = swell_steepness * 0.4 / k2;
	vec3 swell = gerstner_offset(world_xz, wave_time, d1, k1, a1, qa1, swell_speed, 0.0)
		+ gerstner_offset(world_xz, wave_time, d2, k2, a2, qa2, swell_speed * SWELL2_SPEED, SWELL2_PHASE);
	crest_pinch = clamp(
		gerstner_pinch(world_xz, wave_time, d1, k1, qa1, swell_speed, 0.0)
		+ gerstner_pinch(world_xz, wave_time, d2, k2, qa2, swell_speed * SWELL2_SPEED, SWELL2_PHASE),
		0.0, 1.0);
	// Combined height normalized against the theoretical crest ceiling so the
	// color bands and whitecaps track the swell, not just the chop.
	wave_value = (chop * wave_height + swell.y) / (wave_height + a1 + a2);

	// World-space offsets applied to model-space VERTEX: both scene ocean
	// planes are translation-only, so the axes line up.
	VERTEX.x += swell.x;
	VERTEX.z += swell.z;
	VERTEX.y += chop * wave_height + swell.y;
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
	// Swell slopes join the chop slopes; the pinch tips the normal off
	// vertical at crests so their shading sharpens the way the geometry does.
	vec2 d1 = normalize(swell_direction);
	vec2 d2 = swell2_direction();
	float k1 = TAU / swell_wavelength;
	float k2 = TAU / (swell_wavelength * SWELL2_WAVELENGTH);
	float a1 = swell_amplitude;
	float a2 = swell_amplitude * SWELL2_AMPLITUDE;
	vec2 swell_slope = gerstner_slope(world_xz, wave_time, d1, k1, a1, swell_speed, 0.0)
		+ gerstner_slope(world_xz, wave_time, d2, k2, a2, swell_speed * SWELL2_SPEED, SWELL2_PHASE);
	vec3 world_normal = normalize(vec3(
		-((slope_x + swell_slope.x) * normal_strength + detail_slope_x * detail_mix),
		max(1.0 - crest_pinch * 0.5, 0.2),
		-((slope_z + swell_slope.y) * normal_strength + detail_slope_z * detail_mix)));
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
	// The Gerstner pinch marks converging water at swell crests — exactly
	// where real foam gathers, so it feeds coverage almost for free.
	float coverage = clamp(foam_coverage + crest01 * foam_crest_boost + crest_pinch * 0.22, 0.0, 1.0);
	float cut = mix(0.97, 0.5, coverage);
	float foam_mask = smoothstep(cut, cut + 0.14, web);

	// Whitecaps on the highest crests: edges broken by the web noise and the
	// interior textured by it too, so caps read as froth instead of flat
	// white cloud-blobs. Attenuated with distance — swell crests span the
	// whole sea now, and full-strength caps merged into a frosty horizon.
	float whitecap = smoothstep(whitecap_threshold, whitecap_threshold + 0.16, wave_value + crest_pinch * 0.3 + (web - 0.55) * 0.45);
	whitecap *= mix(0.5, 1.0, web) * (1.0 - 0.55 * far_mix);

	float band = floor((wave_value + 1.0) * 3.0) / 3.0;
	vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, clamp((wave_value + 1.0) * 0.5 + band * color_band_strength, 0.0, 1.0));
	// Drifting patches of sunlit turquoise; squared so it stays patchy
	// instead of washing the whole sea brighter.
	float tint = fbm(world_xz * color_noise_scale + vec2(wave_time * 0.012, wave_time * 0.009));
	water_color = mix(water_color, subsurface_color.rgb, clamp(tint * tint * color_noise_strength * (0.55 + 0.45 * crest01), 0.0, 1.0));
	// Lean the far field toward deep blue before fog blends in: the swell
	// ridges at the horizon otherwise fog up into frosty white hills.
	water_color = mix(water_color, deep_color.rgb, far_mix * 0.35);

	// Fresnel fades with distance: the swell tilts far-field normals enough
	// that the grazing-angle highlight washed the whole horizon pale mint.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float foam_total = clamp(foam_mask * foam_opacity + whitecap * 0.8, 0.0, 1.0);
	vec3 surface = mix(water_color, highlight_color.rgb, clamp(fresnel * mix(0.22, 0.1, far_mix), 0.0, 1.0));
	ALBEDO = mix(surface, foam_color.rgb, foam_total);
	// Foam is matte; open water keeps the tight sun glints. Specular kept
	// modest — the smooth swell faces otherwise ignite into one huge bloom
	// blob where they align with the sun.
	ROUGHNESS = mix(glint_roughness, 0.85, foam_total);
	SPECULAR = mix(0.08, 0.02, foam_total);
}
