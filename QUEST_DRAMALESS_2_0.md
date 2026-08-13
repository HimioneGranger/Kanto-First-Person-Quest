# Dramaless 2.0 Quest compatibility

This Quest fork adapts Kanto in First Person 1.60.0 to the accepted Dramaless
2.0 Quest q3 core baseline at commit `1b3ac8c`. Kanto packages q3 and q4 retain
the q2 source adaptation and change only importer-facing archive format. q3
restored the upstream folder layout; after Android still rejected its
Windows/FAT-origin headers, q4 reproduces the Unix-origin header style of the
known-working official archive. q5 retains that package format and removes one
optional battle-only flora injection after physical Route 8 evidence showed it
occluding Dramaless 2.0's native battle camera.

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
  Dramaless 2.0. q4 initially adapted the optional raised-flora hook to that
  file, but repeatable Route 8 captures showed a large nearby world prop
  covering the arena. q5 preserves the 2.0 provider exactly and removes only
  q4's marked `__ds_btl_props` block from an upgraded installation. Older
  tested `BattleScene.lua` providers retain the established raised-stem hook.
  StadiumBattleFX remains a separate host/importer and is not absorbed here.

## Safety and rollback

Unknown versions retain the existing pure-refusal behavior. Version `2.0.0`
is accepted only because the q3 anchor contract is checked by
`tools/test_dramaless_2_0.py` before packaging. Base-owned Structures,
ChunkMesher, VoxelScene, FirstPerson, and main sources receive pristine
in-place backups before their first write. A battle-provider backup created by
q4 is retained through q5's narrow cleanup, so the normal explicit REMOVE PATCH
path still restores the original bytes. A fresh q5 install never writes or
backs up Dramaless 2.0's native battle provider.

No ROM, save, generated cache, APK, or commercial game data belongs in this
repository or package. The user's normal Gen1Recomp ROM-import workflow is
unchanged.
