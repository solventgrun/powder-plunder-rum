"""Shared review-render rig: warm studio lighting, ortho camera, clay pass."""
import math

import bpy

from .materials import mat
from .primitives import look_at


def setup_review_scene():
    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.samples = 128
    bpy.context.scene.render.film_transparent = False
    bpy.context.scene.view_settings.view_transform = "Standard"
    bpy.context.scene.view_settings.look = "Medium High Contrast"
    bpy.context.scene.view_settings.exposure = 0.25
    bpy.context.scene.view_settings.gamma = 1.0
    bpy.context.scene.world.color = (0.58, 0.55, 0.50)
    bpy.context.scene.render.resolution_x = 2800
    bpy.context.scene.render.resolution_y = 1700

    bpy.ops.object.light_add(type="AREA", location=(-4.8, 6.2, -5.6))
    key = bpy.context.object
    key.name = "Large warm soft key light"
    key.data.energy = 3600
    key.data.size = 7.5
    key.data.color = (1.0, 0.82, 0.60)
    bpy.ops.object.light_add(type="AREA", location=(5.2, 4.0, 4.4))
    fill = bpy.context.object
    fill.name = "Broad neutral fill light"
    fill.data.energy = 2100
    fill.data.size = 9.0
    fill.data.color = (0.82, 0.88, 1.0)
    bpy.ops.object.light_add(type="AREA", location=(-2.2, 3.7, 4.8))
    top = bpy.context.object
    top.name = "Soft overhead reveal light"
    top.data.energy = 900
    top.data.size = 6.0
    top.data.color = (1.0, 0.92, 0.78)
    bpy.ops.object.light_add(type="POINT", location=(3.0, 2.8, 2.8))
    rim = bpy.context.object
    rim.name = "Small gold rim light"
    rim.data.energy = 380
    rim.data.color = (1.0, 0.76, 0.42)

    bpy.ops.object.camera_add(location=(-8.2, 1.52, -0.45))
    camera = bpy.context.object
    camera.name = "Camera_primary_centered_hull_review"
    look_at(camera, (0, 0.92, -0.45))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 9.05
    bpy.context.scene.camera = camera

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0, 0.55, 0))
    bpy.context.object.name = "Origin_waterline_center_reference"
    return camera


def render_to(path, camera_location, target, ortho_scale, roll_degrees=0.0):
    camera = bpy.context.scene.camera
    camera.location = camera_location
    look_at(camera, target)
    if roll_degrees:
        camera.rotation_euler.rotate_axis("Z", math.radians(roll_degrees))
    camera.data.ortho_scale = ortho_scale
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def render_clay(path, camera_location, target, ortho_scale, roll_degrees=90.0):
    clay = mat("inspection warm clay", (0.62, 0.58, 0.52, 1), 0.72)
    dark_clay = mat("inspection dark recess", (0.20, 0.18, 0.16, 1), 0.85)
    for obj in bpy.context.scene.objects:
        if hasattr(obj.data, "materials"):
            obj.data.materials.clear()
            obj.data.materials.append(dark_clay if "black" in obj.name.lower() or "recess" in obj.name.lower() else clay)
    render_to(path, camera_location, target, ortho_scale, roll_degrees)
