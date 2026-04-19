#!/usr/bin/env python3
"""
Headless Blender turntable renderer for .glb/.gltf assets.

Usage:
  blender -b -P tools/blender_turntable.py -- \
    --input assets/ice_cream_truck.glb \
    --output-dir assets/renders/ice_cream_truck \
    --frames 36 --size 768
"""

import argparse
import math
import os
import sys

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []

    parser = argparse.ArgumentParser(description="Render a transparent PNG turntable from a GLB/GLTF file.")
    parser.add_argument("--input", required=True, help="Path to input .glb/.gltf file.")
    parser.add_argument("--output-dir", required=True, help="Directory to store rendered PNG frames.")
    parser.add_argument("--frames", type=int, default=36, help="Number of frames in one 360 turn.")
    parser.add_argument("--size", type=int, default=768, help="Square output size in pixels.")
    parser.add_argument(
        "--model-tilt-deg",
        type=float,
        default=-8.0,
        help="Static X tilt applied to model while spinning.",
    )
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for datablocks in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.textures,
        bpy.data.images,
        bpy.data.lights,
        bpy.data.cameras,
    ):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def set_render_engine(scene: bpy.types.Scene) -> None:
    engines = [e.identifier for e in scene.render.bl_rna.properties["engine"].enum_items]
    if "BLENDER_EEVEE" in engines:
        scene.render.engine = "BLENDER_EEVEE"
    elif "BLENDER_EEVEE_NEXT" in engines:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    elif "CYCLES" in engines:
        scene.render.engine = "CYCLES"
    else:
        raise RuntimeError(f"No supported render engine found. Available: {engines}")


def import_model(path: str) -> list[bpy.types.Object]:
    ext = os.path.splitext(path)[1].lower()
    if ext not in {".glb", ".gltf"}:
        raise ValueError(f"Unsupported model extension: {ext}")

    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=path)
    after = set(bpy.data.objects.keys())
    imported_names = after - before
    imported = [bpy.data.objects[name] for name in imported_names]
    if not imported:
        raise RuntimeError(f"No objects imported from {path}")
    return imported


def top_level_for_root(imported: list[bpy.types.Object]) -> list[bpy.types.Object]:
    imported_set = set(imported)
    top = []
    for obj in imported:
        if obj.parent is None or obj.parent not in imported_set:
            top.append(obj)
    return top


def create_turntable_root(imported: list[bpy.types.Object]) -> bpy.types.Object:
    root = bpy.data.objects.new("TurntableRoot", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in top_level_for_root(imported):
        obj.parent = root
    return root


def renderable_objects(scope: list[bpy.types.Object]) -> list[bpy.types.Object]:
    return [obj for obj in scope if obj.type in {"MESH", "CURVE", "SURFACE", "META", "FONT"}]


def collect_world_bbox_points(objects: list[bpy.types.Object]) -> list[Vector]:
    points: list[Vector] = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    return points


def bbox_center_and_size(points: list[Vector]) -> tuple[Vector, Vector]:
    xs = [p.x for p in points]
    ys = [p.y for p in points]
    zs = [p.z for p in points]
    p_min = Vector((min(xs), min(ys), min(zs)))
    p_max = Vector((max(xs), max(ys), max(zs)))
    center = (p_min + p_max) * 0.5
    size = p_max - p_min
    return center, size


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_lights() -> None:
    scene = bpy.context.scene

    key_data = bpy.data.lights.new("Key", type="AREA")
    key_data.energy = 1200
    key_data.size = 4.0
    key = bpy.data.objects.new("KeyLight", key_data)
    key.location = (4.5, -6.0, 5.5)
    scene.collection.objects.link(key)

    fill_data = bpy.data.lights.new("Fill", type="AREA")
    fill_data.energy = 450
    fill_data.size = 6.0
    fill = bpy.data.objects.new("FillLight", fill_data)
    fill.location = (-5.0, -4.0, 3.2)
    scene.collection.objects.link(fill)

    rim_data = bpy.data.lights.new("Rim", type="AREA")
    rim_data.energy = 700
    rim_data.size = 3.5
    rim = bpy.data.objects.new("RimLight", rim_data)
    rim.location = (-1.0, 6.2, 4.8)
    scene.collection.objects.link(rim)


def setup_camera(radius: float) -> bpy.types.Object:
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Camera")
    cam_obj = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    cam_data.lens = 50
    fov = cam_data.angle
    distance = max(2.2, (radius / math.sin(fov * 0.5)) * 1.25)
    cam_obj.location = Vector((0.0, -distance, radius * 0.38))
    look_at(cam_obj, Vector((0.0, 0.0, 0.0)))
    return cam_obj


def configure_render(size: int) -> None:
    scene = bpy.context.scene
    set_render_engine(scene)

    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 15


def main() -> None:
    args = parse_args()
    input_path = os.path.abspath(args.input)
    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    clear_scene()
    imported = import_model(input_path)
    root = create_turntable_root(imported)

    renderables = renderable_objects(imported)
    if not renderables:
        raise RuntimeError("Imported scene has no renderable mesh objects.")

    bpy.context.view_layer.update()
    points = collect_world_bbox_points(renderables)
    if not points:
        raise RuntimeError("Unable to compute mesh bounds.")

    center, size = bbox_center_and_size(points)
    root.location = -center
    bpy.context.view_layer.update()

    points = collect_world_bbox_points(renderables)
    _, size = bbox_center_and_size(points)
    max_dim = max(size.x, size.y, size.z)
    if max_dim <= 0:
        raise RuntimeError("Invalid model dimensions.")
    target_dim = 2.2
    uniform_scale = target_dim / max_dim
    root.scale = Vector((uniform_scale, uniform_scale, uniform_scale))
    bpy.context.view_layer.update()

    points = collect_world_bbox_points(renderables)
    radius = max(p.length for p in points)

    setup_lights()
    setup_camera(radius)
    configure_render(args.size)

    stem = os.path.splitext(os.path.basename(input_path))[0]
    for idx in range(args.frames):
        angle = (idx / args.frames) * math.tau
        root.rotation_euler = Vector((math.radians(args.model_tilt_deg), 0.0, angle))
        bpy.context.view_layer.update()
        out_file = os.path.join(output_dir, f"{stem}_{idx:03d}.png")
        bpy.context.scene.render.filepath = out_file
        bpy.ops.render.render(write_still=True)
        print(f"Rendered {out_file}")

    print(f"Done: {args.frames} frames -> {output_dir}")


if __name__ == "__main__":
    main()
