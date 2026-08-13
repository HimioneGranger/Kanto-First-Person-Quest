# Dramaless 2.0 Quest compatibility

This Quest fork adapts Kanto in First Person 1.60.0 to the accepted Dramaless
2.0 Quest q3 core baseline at commit `1b3ac8c`. Kanto packages q3 and q4 retain
the q2 source adaptation and change only importer-facing archive format. q3
restored the upstream folder layout; after Android still rejected its
Windows/FAT-origin headers, q4 reproduces the Unix-origin header style of the
known-working official archive. q5 tested removal of one optional battle-only
flora injection, but physical logs proved the removal succeeded while the same
Route 8 obstruction remained. q6 supersedes that rejected diagnosis with a
per-arena camera-clearance fix.

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
  Dramaless 2.0. The optional raised-flora hook targets that provider so lifted
  rounds keep their trunks, stone supports, hoods and shadows during battles.
  q5 temporarily removed it, but device evidence proved the terrain canopy—not
  the support draw—still blocked Route 8. q6 restores the support hook.
  StadiumBattleFX remains a separate host/importer and is not absorbed here.
- `data/battle_arenas.lua`: Kanto's lifted Route 8 terrain intersects the
  default telephoto rig, whose eye stands roughly five blocks from the arena.
  q6 changes only Route 8 to Dramaless's existing authored `cam = "wide"` rig.
  Global battle-camera constants, VR matrices and every other arena stay native.

## Safety and rollback

Unknown versions retain the existing pure-refusal behavior. Version `2.0.0`
is accepted only because the q3 anchor contract is checked by
`tools/test_dramaless_2_0.py` before packaging. Base-owned Structures,
ChunkMesher, VoxelScene, FirstPerson, main, the battle provider and battle arena
data receive pristine in-place backups before their first write. q6 retains an
existing q4/q5 battle backup and creates the arena-data backup only when its
Route 8 override applies. The normal explicit REMOVE PATCH path restores every
base-owned file byte-for-byte.

No ROM, save, generated cache, APK, or commercial game data belongs in this
repository or package. The user's normal Gen1Recomp ROM-import workflow is
unchanged.
