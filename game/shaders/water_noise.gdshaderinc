// Shared value-noise toolkit for the water shaders (ocean surface + wake
// foam), so both speak the same foam language.

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
