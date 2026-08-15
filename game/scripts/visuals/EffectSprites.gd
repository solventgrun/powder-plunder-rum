class_name EffectSprites
extends RefCounted

# Shared procedurally generated particle sprites (no texture pipeline — the
# retro look stays code-built). Built once, cached for every effect instance.

static var _puff: ImageTexture
static var _ring: ImageTexture


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
