# Dramaless 2.0 Quest compatibility

This Quest fork adapts Kanto in First Person 1.60.0 to the accepted Dramaless
2.0 Quest q3 core baseline at commit `1b3ac8c`. Kanto package q3 retains the
q2 source adaptation and changes only the importer-facing archive format after
the physical Quest rejected q2's PowerShell-written flat-root ZIP.

## Audited seams

- `VoxelScene.lua`: Dramaless 2.0 retained the primary terrain draw but added a
  render-distance guard around neighbour terrain. The Kanto layers now match
  that whole block explicitly. Backdrop and sky remain before terrain;
  ceiling and flora remain after every admitted neighbour mesh.
- `FirstPerson.lua`: the Voxel3D require, eye-height expression, and head X/Z
  expressions used by the jump/sway patch remain exact single matches.
- `main.lua`: the settings table and VoxelGrid row remain exact single matches.
- `Structures.lua` and `ChunkMesher.lua`: the single/grouped round-stamp,
  round-stamp height, and idle-slice anchors remain exact single matches.
- `VoxelScene.lua` shadow pass: the water shadow draw remains an exact single
  match for Kanto's optional flora shadow hook.
- Battle rendering moved from `BattleScene.lua` to `VoxelBattleScene.lua` in
  Dramaless 2.0. The patch now supports the new provider file and indentation
  while retaining the old path for older tested bases. StadiumBattleFX remains
  the host/importer; Kanto only adds its optional flora draw after the native
  arena terrain.

## Safety and rollback

Unknown versions retain the existing pure-refusal behavior. Version `2.0.0`
is accepted only because the q3 anchor contract is checked by
`tools/test_dramaless_2_0.py` before packaging. Base-owned Structures,
ChunkMesher, VoxelScene, FirstPerson, main, and battle-provider sources receive
pristine in-place backups before their first write. The normal explicit REMOVE
PATCH path can therefore restore exact source rather than guessing.

No ROM, save, generated cache, APK, or commercial game data belongs in this
repository or package. The user's normal Gen1Recomp ROM-import workflow is
unchanged.
