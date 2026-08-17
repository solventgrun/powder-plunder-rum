shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Wake ribbon foam: the flat translucent strip read as a ghost wedge next to
// the textured ocean, so the ribbon now carries the same ridged-web foam
// language, world-anchored so the pattern stays put as the ship sails on.
// TIME is safe here — nothing samples the wake on the CPU.

#include "res://game/shaders/water_noise.gdshaderinc"

uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 0.97, 1.0);
uniform float max_opacity : hint_range(0.0, 1.0) = 0.92;
uniform float noise_scale = 0.85;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// COLOR.a carries age fade (1 fresh -> 0 gone); COLOR.r carries lay
	// strength (how hard the water was churned when the point was laid).
	float life = COLOR.a;
	float lay = COLOR.r;
	// Soft lateral feather so the ribbon has no geometric edge.
	float edge = smoothstep(0.0, 0.32, UV.x) * smoothstep(1.0, 0.68, UV.x);
	vec2 p = world_xz * noise_scale;
	float n1 = fbm(p + vec2(TIME * 0.1, -TIME * 0.07));
	float n2 = fbm(p * 1.7 + vec2(-TIME * 0.08, TIME * 0.06) + vec2(3.1));
	float web = (1.0 - abs(n1 * 2.08 - 1.0)) * (1.0 - abs(n2 * 2.08 - 1.0));
	// Fresh, centered wake keeps a low cut (near-solid froth); as it ages
	// and spreads the cut rises and the band dissolves into torn lace.
	float density = life * edge;
	// The web noise concentrates around 0.6-0.9, so the fresh-end cut must
	// sit inside that band or the fresh trail collapses into a solid runway.
	float cut = mix(0.72, 0.5, density);
	float mask = smoothstep(cut, cut + 0.24, web);
	// Solid boil hugging the stern so the trail is born creamy. Keep the ramp
	// inside the last ~fifth of life: any wider and the boil IS the trail —
	// a solid white runway with the lace relegated to the tail.
	float boil = smoothstep(0.8, 0.97, life) * edge * 0.85;
	// Churned underlay: a faint bed keeps the trail reading as one connected
	// band — pure lace blended into the ocean's own crest foam (2026-08-16
	// playtest: "hard to see") — without flattening it into a solid runway.
	float bed = 0.18 * density;
	// V-arms: persistent bright rails along the ribbon edges. Linear features
	// are the wake's signature — the ocean's blotch foam can't fake them, so
	// the trail stays identifiable even in a busy whitecap field.
	float side = abs(UV.x - 0.5) * 2.0;
	float rail = smoothstep(0.45, 0.62, side) * smoothstep(0.85, 0.68, side)
		* life * (0.7 + 0.3 * web);
	ALBEDO = foam_color.rgb;
	ALPHA = clamp(mask * (0.62 + 0.38 * density) + boil + bed * (1.0 - mask) + rail * 0.85, 0.0, 1.0)
		* max_opacity * smoothstep(0.0, 0.12, life) * mix(0.55, 1.0, lay);
}
