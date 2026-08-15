"""Stylized rope rigging: sagging runs bundled into one object per group."""
import math

import bpy
from mathutils import Vector


def rope_points(start, end, drop=0.03, samples=5):
    # Straight run with a light parabolic sag so lines read as rope, not wire.
    start = Vector(start)
    end = Vector(end)
    pts = []
    for i in range(samples):
        t = i / (samples - 1)
        p = start.lerp(end, t)
        p.y -= drop * math.sin(math.pi * t)
        pts.append(tuple(p))
    return pts


def add_rope_bundle(name, ropes, radius, material):
    # One curve object holding every rope of a rigging group as its own POLY
    # spline — the group exports as a single mesh with no per-rope objects.
    curve = bpy.data.curves.new(f"{name}Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    for pts in ropes:
        spline = curve.splines.new("POLY")
        spline.points.add(len(pts) - 1)
        for point, co in zip(spline.points, pts):
            point.co = (co[0], co[1], co[2], 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(material)
    return obj
