#!/usr/bin/env python3
"""Focused, ROM-free compatibility contract for Dramaless 2.0 Quest q3."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def once(text: str, needle: str, label: str) -> None:
    count = text.count(needle)
    require(count == 1, f"{label}: expected one match, found {count}")


def long_string(source: str, name: str) -> str:
    match = re.search(rf"local {re.escape(name)} = \[\[(.*?)\]\]", source, re.S)
    require(match is not None, f"Kanto source is missing {name}")
    return match.group(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dramaless",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "Dramaless-Quest",
    )
    args = parser.parse_args()

    kanto = Path(__file__).resolve().parents[1]
    dramaless = args.dramaless.resolve()
    source = (kanto / "main.lua").read_text(encoding="utf-8")
    manifest = json.loads((dramaless / "manifest.json").read_text(encoding="utf-8"))
    require(
        manifest.get("id") == "DRAMALESS_SHAPE"
        and manifest.get("version") == "2.0.0-quest.3",
        "test must target the accepted Dramaless 2.0 Quest q3 source",
    )
    require('["2.0.0"] = true' in source, "2.0.0 is not in Kanto's audited table")

    voxel_scene = (dramaless / "lib" / "VoxelScene.lua").read_text(encoding="utf-8")
    scene_anchor = long_string(source, "SCENE_2_ANCHOR")
    once(voxel_scene, scene_anchor, "Dramaless 2.0 scene block")
    require("withinRenderDistance" in scene_anchor, "scene block lost 2.0 culling")

    add_match = re.search(
        r"local SCENE_2_ADD = \[\[(.*?)\]\] \.\. SCENE_2_ANCHOR \.\. \[\[(.*?)\]\]",
        source,
        re.S,
    )
    require(add_match is not None, "cannot parse SCENE_2_ADD")
    patched_scene = voxel_scene.replace(
        scene_anchor, add_match.group(1) + scene_anchor + add_match.group(2), 1
    )
    once(patched_scene, "pcall(Backdrop.draw, state)", "backdrop draw")
    once(patched_scene, "pcall(SkyLayer.draw, state)", "sky draw")
    once(patched_scene, "pcall(Ceiling.draw, state, atlasFor)", "ceiling draw")
    once(patched_scene, "pcall(Flora.draw, state, atlasFor)", "flora draw")
    require(
        patched_scene.index("pcall(Backdrop.draw, state)")
        < patched_scene.index("Voxel3D.draw(terrain, atlasFor(state.map), nil)")
        < patched_scene.index("pcall(Ceiling.draw, state, atlasFor)"),
        "Kanto layers do not surround the complete 2.0 terrain block",
    )
    require(
        patched_scene.index("Mat4.translate(nb.ox, 0, nb.oy)")
        < patched_scene.index("pcall(Ceiling.draw, state, atlasFor)"),
        "ceiling/flora were inserted before admitted neighbour terrain",
    )

    first_person = (dramaless / "lib" / "FirstPerson.lua").read_text(encoding="utf-8")
    for needle, label in (
        ('local Voxel3D = V.require("Voxel3D")', "first-person require"),
        ("(me.gh or 0) + (me.lift or 0) + FirstPerson.EYE_HEIGHT", "eye height"),
        ("head = { me.px + 8,", "head X"),
        ("             me.py + 8 }", "head Z"),
    ):
        once(first_person, needle, label)

    dramaless_main = (dramaless / "main.lua").read_text(encoding="utf-8")
    once(
        dramaless_main,
        'local SETTINGS = {\n  { VoxelGrid.setting, "One-pixel wireframe along every voxel edge." },',
        "settings row",
    )

    structures = (dramaless / "lib" / "Structures.lua").read_text(encoding="utf-8")
    once(
        structures,
        "          S.roundStamps[#S.roundStamps + 1] =\n"
        "            { quads = tpl.quads, mx = cx * 16 + 8, mz = cy * 16 + 8 }",
        "single round-stamp tree",
    )
    once(
        structures,
        "              { quads = tpl.quads, mx = cx * 16 + 16, mz = cy * 16 + 16,\n"
        "                r = 16 }",
        "grouped round-stamp tree",
    )

    mesher = (dramaless / "lib" / "ChunkMesher.lua").read_text(encoding="utf-8")
    once(mesher, "          s2[2] = c[2]\n", "round-stamp height")
    once(mesher, "local IDLE_SLICE = 0.005\n", "idle mesh slice")

    once(
        voxel_scene,
        "  ShadowMap.draw(water, atlasFor(state.map), nil)\n",
        "sun shadow pass",
    )

    battle_path = dramaless / "lib" / "VoxelBattleScene.lua"
    require(battle_path.is_file(), "Dramaless 2.0 VoxelBattleScene.lua is missing")
    battle = battle_path.read_text(encoding="utf-8")
    once(
        battle,
        "    Voxel3D.draw(terrain, atlasFor(host), nil)\n",
        "2.0 native-card battle terrain",
    )
    require(
        'base .. "/lib/VoxelBattleScene.lua"' in source,
        "Kanto patcher does not restore the 2.0 battle tree-support provider",
    )
    require(
        "__ds_btl_props" in source and "live.Flora.battleProps(host, neighbors)" in source,
        "Kanto battle tree-support call is missing",
    )

    arena_data = (dramaless / "data" / "battle_arenas.lua").read_text(encoding="utf-8")
    require(
        '  ["ROUTE_8"] = { x = 25, y = 7, shape = "wide" },' in arena_data,
        "accepted Dramaless Route 8 arena anchor changed",
    )
    battle_cam = (dramaless / "lib" / "BattleCam.lua").read_text(encoding="utf-8")
    require(
        re.search(r"\n\s*wide\s*=\s*\{", battle_cam) is not None,
        "Dramaless wide battle rig is missing",
    )
    require(
        "__ds_r8_wide" in source
        and 'base .. "/data/battle_arenas.lua"' in source
        and 'cam = "wide"' in source,
        "Kanto Route 8 camera-clearance patch is missing",
    )

    voxel3d = (dramaless / "lib" / "Voxel3D.lua").read_text(encoding="utf-8")
    for symbol in ("pushQuad", "newMesh", "draw"):
        require(
            re.search(rf"function Voxel3D\.{symbol}\b", voxel3d) is not None,
            f"payload dependency Voxel3D.{symbol} is missing",
        )
    for module in ("Mat4", "TileShape", "ModSetting", "DayNight", "ThirdPerson"):
        require((dramaless / "lib" / f"{module}.lua").is_file(), f"missing {module}.lua")

    for engine_file in (
        "Structures.lua",
        "ChunkMesher.lua",
        "VoxelBattleScene.lua",
        "battle_arenas.lua",
    ):
        require(
            "backupInPlace" in source,
            f"rollback backup helper missing before {engine_file} adaptation",
        )
    require(
        "NOTHING -- no files touched. An update will follow." in source,
        "unknown-version safe-refusal contract is missing",
    )

    print("PASS: Dramaless 2.0 q3 anchors, ordering, payload API and rollback contract")


if __name__ == "__main__":
    main()
