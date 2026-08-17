class_name EffectSprites
extends RefCounted

# Shared procedurally generated particle sprites (no texture pipeline — the
# retro look stays code-built). Built once, cached for every effect instance.

static var _puff: ImageTexture
static var _ring: ImageTexture
static var _tatter: ImageTexture


# Soft radial falloff disc; without it billboard quads show square corners.
static func puff_texture() -> ImageTexture:
	if _puff:
		return _puff
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (float(size) - 1.0) * 0.5
	for y in range(size):
		for x in range(size):
			var distance := Vector2(float(x) - center, float(y) - center).length() / center
			var alpha := clampf(1.0 - distance, 0.0, 1.0)
			alpha = alpha * alpha * (3.0 - 2.0 * alpha)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_puff = ImageTexture.create_from_image(image)
	return _puff


# Seamless cellular-noise alpha field for sail canvas. Cell centers sit at
# alpha ~0, so a rising alpha-scissor threshold eats round-ish shot holes
# that grow and merge — progressive chain-shot damage without a UV layout
# (the material samples it triplanar in world space).
static func canvas_tatter_texture() -> ImageTexture:
	if _tatter:
		return _tatter
	var noise := FastNoiseLite.new()
	noise.seed = 71
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.frequency = 0.09
	noise.fractal_octaves = 2
	var size := 128
	var field := noise.get_seamless_image(size, size)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, field.get_pixel(x, y).r))
	_tatter = ImageTexture.create_from_image(image)
	return _tatter


# Soft ring band, for expanding foam rings laid flat on the water.
static func ring_texture() -> ImageTexture:
	if _ring:
		return _ring
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (float(size) - 1.0) * 0.5
	for y in range(size):
		for x in range(size):
			var distance := Vector2(float(x) - center, float(y) - center).length() / center
			var band := 1.0 - clampf(absf(distance - 0.7) / 0.24, 0.0, 1.0)
			band = band * band * (3.0 - 2.0 * band)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, band))
	_ring = ImageTexture.create_from_image(image)
	return _ring
