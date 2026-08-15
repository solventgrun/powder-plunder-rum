"""Mast assemblies and other deck fittings shared across ship classes."""
from .primitives import add_cube, add_cylinder_between, add_ellipsoid, add_spar


def add_mast_assembly(form, name, z, total_height, base_radius, materials, square_yards=(), lateen=False):
    # Full mast: tapered lower mast rising from the deck partner, a round top
    # platform, an overlapping tapered topmast with a gold doubling band, and a
    # gold masthead finial. Square-rig masts get course/topsail yards across x;
    # a lateen mast gets a raked lateen yard instead. Heights are fractions of
    # total_height above the deck so all masts share proportions.
    dark = materials["dark_wood"]
    gold = materials["gold"]
    black = materials["black"]
    _, deck_y, _ = form.side_point(z, 1, 0.985, -0.020)
    base_y = deck_y - 0.075
    top_y = deck_y + total_height
    lower_top = deck_y + total_height * 0.60

    # Deck partner hardware (classified under Deck: it stays when a mast hides).
    add_cube(f"MastPartner_dark_socket_{name}", (0, deck_y + 0.015, z), (base_radius * 3.4, 0.060, base_radius * 3.4), dark, 0.014)
    add_cube(f"MastPartner_shadow_recess_{name}", (0, deck_y + 0.052, z), (base_radius * 2.45, 0.020, base_radius * 2.45), black, 0.008)
    add_cylinder_between(f"MastPartner_gold_front_band_{name}", (-base_radius * 1.9, deck_y + 0.066, z - base_radius * 1.9), (base_radius * 1.9, deck_y + 0.066, z - base_radius * 1.9), 0.010, gold, 8)
    add_cylinder_between(f"MastPartner_gold_back_band_{name}", (-base_radius * 1.9, deck_y + 0.066, z + base_radius * 1.9), (base_radius * 1.9, deck_y + 0.066, z + base_radius * 1.9), 0.010, gold, 8)

    add_spar(f"Mast_lower_{name}", (0, base_y, z), (0, lower_top, z), base_radius, base_radius * 0.62, dark, 18)
    band_y = deck_y + min(0.32, total_height * 0.34)
    add_cylinder_between(f"gold_mast_band_{name}", (0, band_y - 0.016, z), (0, band_y + 0.016, z), base_radius * 1.06, gold, 14)

    platform_r = base_radius * 1.85
    add_cylinder_between(f"Mast_top_platform_{name}", (0, lower_top - 0.062, z), (0, lower_top - 0.022, z), platform_r, dark, 18)
    add_cylinder_between(f"Mast_top_platform_gold_rim_{name}", (0, lower_top - 0.070, z), (0, lower_top - 0.058, z), platform_r * 1.03, gold, 18)

    topmast_base = lower_top - total_height * 0.08
    add_spar(f"Mast_topmast_{name}", (0, topmast_base, z), (0, top_y, z), base_radius * 0.55, base_radius * 0.30, dark, 14)
    add_cylinder_between(f"Mast_doubling_gold_band_{name}", (0, lower_top - 0.115, z), (0, lower_top - 0.085, z), base_radius * 0.80, gold, 14)
    add_ellipsoid(f"Mast_head_gold_finial_{name}", (0, top_y + 0.035, z), (0.030, 0.040, 0.030), gold, 10, 6)

    def mast_radius_at(y):
        # Piecewise linear taper matching the two spar segments above.
        if y <= lower_top:
            f = (y - base_y) / (lower_top - base_y)
            return base_radius * (1.0 - 0.38 * f)
        f = (y - topmast_base) / (top_y - topmast_base)
        return base_radius * (0.55 - 0.25 * f)

    for suffix, height_fraction, span, radius in square_yards:
        y = deck_y + total_height * height_fraction
        add_cylinder_between(f"Yard_{suffix}_{name}", (-span * 0.5, y, z), (span * 0.5, y, z), radius, dark, 12)
        sling_radius = max(radius * 1.55, mast_radius_at(y) * 1.22)
        add_cylinder_between(f"Yard_{suffix}_gold_sling_{name}", (0, y - 0.030, z), (0, y + 0.030, z), sling_radius, gold, 10)

    if lateen:
        # Raked lateen yard: forward-low to aft-high, crossing the mast a bit
        # above half height; the high end overhangs the stern.
        cross_y = deck_y + total_height * 0.55
        half = 1.02
        dy = 0.67 * half
        dz = 0.74 * half
        add_spar(f"Yard_lateen_{name}", (0, cross_y - dy, z - dz), (0, cross_y + dy, z + dz), 0.027, 0.017, dark, 12)
        add_cylinder_between(f"Yard_lateen_gold_sling_{name}", (0, cross_y - 0.030, z), (0, cross_y + 0.030, z), base_radius * 0.72, gold, 10)
