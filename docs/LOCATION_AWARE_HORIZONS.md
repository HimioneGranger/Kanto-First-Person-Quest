# Location-aware Kanto horizons

Status: design and art-direction prototype; no runtime behavior changed yet.

## Product goal

The outdoor horizon should describe the player's actual place in Kanto. A
player on a route between a city and a forest should see the city in the city
direction and the forest in the forest direction. The same landmark must keep
the same compass bearing when the player crosses a seamless map connection.

This replaces the idea of choosing one unrelated panorama for the whole game.
It does not replace Dramaless weather, sky, day/night, terrain, streaming,
OpenXR, camera, or map ownership.

## Checked source facts

- Gen1Recomp exposes imported Town Map entries through
  `Game.data.field.townMap.locations`. Entries carry stable `x`/`y` grid
  coordinates for outdoor and named indoor locations.
- The live map definition exposes its cardinal connection graph through
  `state.map.def.connections`.
- Gen1Recomp already composes connection offsets in
  `OverworldState.computeNeighbors`; no ROM bytes or extracted map artwork need
  to be copied into this mod.
- The canonical Gen 1 Town Map table places the first test corridor at:

  | Location | X | Y |
  | --- | ---: | ---: |
  | Indigo Plateau | 0 | 2 |
  | Route 23 | 0 | 6 |
  | Route 22 | 0 | 8 |
  | Pewter City | 2 | 3 |
  | Viridian Forest | 2 | 4 |
  | Route 2 | 2 | 6 |
  | Viridian City | 2 | 8 |
  | Route 1 | 2 | 10 |
  | Pallet Town | 2 | 11 |
  | Cinnabar Island | 2 | 15 |

Source reference:
<https://github.com/pret/pokered/blob/master/data/maps/town_map_entries.asm>

The table is used only as factual placement/provenance. No Town Map graphics,
ROM data, official sprites, or extracted artwork will be packaged.

## Runtime design

### One world, modular art

Use a small original-art atlas rather than one 4096x256 panorama per map:

- biome bands: distant forest, rolling route hills, coast, mountain foothills;
- landmark cards: city skyline, forest wall, plateau peaks, island/volcano,
  tower, port, cave mouth, power plant, and other approved silhouettes;
- one shared neutral ground/skirt color derived from the active biome band;
- transparent sky so the existing Dramaless sky/weather remains authoritative.

The first slice covers Pallet Town, Routes 1/2/21/22/23, Viridian City,
Viridian Forest, Pewter City, Cinnabar Island, and Indigo Plateau.

### Stable bearings

Town Map X increases east and Y increases south. For a viewer at `(vx, vy)`
and a landmark at `(lx, ly)`, the landmark bearing is derived from:

```text
east  = lx - vx
north = vy - ly
bearing = atan2(east, north)
```

The current cylinder's world compass orientation remains fixed. The player may
turn freely, but north never becomes east and a map transition never resets the
texture to the player's gaze direction.

The live connection graph refines immediate-neighbor placement. Town Map
coordinates are the stable fallback and the anchor for regions separated by a
gate, cave, building, Fly, or other non-seamless warp.

### Transition continuity

- Keep the previous and destination horizon descriptions for a short bounded
  transition window (target 0.6 seconds).
- Interpolate the viewer's Town Map anchor and landmark bearing/scale rather
  than swapping a whole panorama at the border.
- Cross-fade only when a card changes category or becomes newly visible.
- Never anchor the horizon to current head yaw, recenter yaw, or a single eye.
- Use the same world transform for both eyes; only the OpenXR view/projection
  differs.
- A missing Town Map entry or malformed profile falls back to the accepted
  legacy panorama without disabling the voxel pipeline.

### Quest budget

- One resident landmark atlas, target at most 2048x512 RGBA (4 MiB GPU).
- At most eight visible landmark cards and four biome sectors.
- Build/rebuild a single batched mesh only on map/profile changes, never once
  per eye and never once per frame.
- During the short transition, retain at most the old and new small meshes;
  both use the same atlas. Release the old mesh immediately afterward.
- Target one atlas draw plus the existing ground/skirt draw; a temporary second
  draw is permitted only for transition fading.
- No unique texture per map, unbounded cache, whole-world mesh, physics body,
  emitter, shader compilation, filesystem scan, or ROM-derived cache in the
  package.

## First-region directional contract

- Pallet/Route 1: Viridian is north; Cinnabar is far south across water;
  Indigo's mountains remain west/northwest.
- Viridian/Route 2: Viridian Forest and Pewter are north; Pallet is south;
  Routes 22/23 and the plateau climb are west/northwest.
- Route 2/Forest boundary: the forest wall grows in apparent size toward the
  north and does not jump to a different side after the gate transition.
- The city silhouette recedes behind the player when walking north from
  Viridian and returns at the reciprocal bearing when walking south.
- Connection, building, battle, recenter, sleep/wake, and cold-load events must
  not rotate or reset the horizon.

## Original-art rules

- Original interpretation only: no copied map art, official sprites, logos,
  UI, text, characters, creatures, or traced screenshots.
- Crisp pixel clusters and readable silhouettes at headset distance.
- Favor a GBC/GBA visual language with chunky stepped canopy, rock and
  structure clusters that echo the voxel world; avoid painterly foliage and
  modern high-frequency rendering.
- Transparent background/sky; neutral daylight art that tolerates external
  day/night and weather tinting.
- Avoid tiny detail that shimmers in stereo or disappears after atlas scaling.
- Every source concept, production crop, atlas coordinate and checksum is
  recorded in the repository.

The first concept is
`artwork/concepts/viridian-forest-horizon-v1.png` (2172x724 RGBA, SHA-256
`2E34E7B2FFEA5A6F106F3970886FCFF047A226858386A88717F6F8A641C9EB1C`).
It established the silhouette but was too painterly. The revised
GBC/GBA-and-voxel direction is
`artwork/concepts/viridian-forest-horizon-v2.png` (2172x724 RGBA, SHA-256
`1324C52590DDCCDFB7C4922C4C6CB6E90D7A4F8E756CA85E1B66B8367534B93C`).
Some broadleaf tiers in v2 shared long vertical boundaries and read as stacked
columns. The naturalized revision staggers and interlocks those canopy edges:
`artwork/concepts/viridian-forest-horizon-v3.png` (2172x724 RGBA, SHA-256
`F2791F6A3DFB6DC118A6D447C7D9EB89B30E6DA90E33A9B0DF06EA9ED87BE9C0`).
All three are art-direction sources, not yet shipped runtime textures.

## Acceptance tests

### Automated

- cardinal and diagonal bearing math;
- reciprocal bearings across adjacent maps;
- Town Map nested/direct entry shapes and missing-entry fallback;
- map transition interpolation, timeout, and resource release;
- same world landmark transform supplied to both eyes;
- visible-card and texture-memory caps;
- legacy panorama unchanged when world horizons are disabled;
- no ROM, save, generated cache, official art, or private material in package.

### Physical Quest 3

1. Face north/south in Pallet, Route 1, Viridian, Route 2 and the Forest gates.
2. Confirm forest, city, plateau and Cinnabar bearings against the Town Map.
3. Cross every connection in both directions without a horizon jump or yaw
   reset.
4. Recenter while facing away from north; the world recenters but compass
   landmark relationships remain coherent.
5. Enter/exit buildings, battle twice, sleep/wake controllers, and cold-load a
   save in each side of a transition.
6. Compare frame time, FPS, PSS, graphics memory and shimmer against the
   accepted legacy panorama. Do not promote without device evidence.
