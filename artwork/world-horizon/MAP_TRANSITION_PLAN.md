# Kanto horizon transition plan

Status: art and integration planning only. Do not wire this into the current
Quest payload while the Kanto in First Person rewrite is pending.

## Decision

The location-aware artwork is a **horizon profile layer**, not a replacement
for Dramaless sky, weather, time-of-day, or lighting. Its sky remains
transparent. “Skybox” below means the distant biome and landmark artwork that
sits beneath the existing Dramaless sky.

There are two different kinds of map change:

1. **Open connection:** the player walks across a route or town boundary with
   no fade. The engine swaps maps during the same walking step. A horizon must
   remain continuous here. It may interpolate landmark position and scale, but
   it must not synchronously load or abruptly replace a texture.
2. **Covered warp:** a door, cave, gate, ladder, elevator, Fly, Teleport, Dig,
   Escape Rope, blackout, boot, or save load covers the view with a transition.
   This is a safe point to select a substantially different horizon profile.
   Assets should still be resident or prefetched; filesystem and GPU work must
   not be placed on the visible frame boundary.

The runtime authority is the engine's `map.entered` event:

- `via = "connection"` means continuous art only;
- `via = "warp"` or another covered travel mode permits a hard profile change;
- `via = "boot"` initializes the correct profile behind the loading veil.

Do not infer this solely from map names. Several Yellow headers declare map
connections for neighbor rendering even where terrain, a gate, or progression
prevents a normal edge crossing. The eventual implementation must trust the
live `via` value.

## Safe horizon-change windows

These are the useful Kanto transition families for artwork planning.

| Covered transition | Horizon use |
| --- | --- |
| Route 2 -> Viridian Forest North/South Gate -> Viridian Forest | Load the dedicated enclosed-forest profile while the gate covers the view. Keep north/south landmark bearings consistent when returning. |
| Fuchsia City -> Safari Zone Gate -> Safari Zone Center | Load one shared Safari profile. Center/East/North/West should retain that family across their internal warps. |
| Route 4 entrances -> Mt. Moon -> Route 4 exits | The cave is a long hidden bridge between west/east mountain views. Preselect the destination-side mountain profile before exiting. |
| Route 2 -> Diglett's Cave -> Route 11 | Safe long-distance change between the northwest and Vermilion/east-coast profiles. |
| Route 5 -> Underground Path -> Route 6 | Safe north/central-to-south profile change. |
| Route 7 -> Underground Path -> Route 8 | Safe west-to-east profile change. |
| Routes 5/6/7/8 -> their gatehouses -> Saffron City | Select the Saffron urban profile inside the gate; select the appropriate route profile on the return trip. |
| Route 10 entrances -> Rock Tunnel -> Route 10 exits | Safe covered transition, although both exits remain in the same broad northeast/east family. |
| Route 20 entrances -> Seafoam Islands -> Route 20 exits | Safe covered transition between the east/west sides of the sea corridor. |
| Route 22 -> Route 22 Gate / badge gates -> Route 23; Route 23 -> Victory Road -> Indigo Plateau | Safe opportunities for the League/plateau profile. The declared Route 22/23 and Route 23/Indigo connections remain continuity constraints if the live engine reports `connection`. |
| Routes 11/12/15/16/18 -> route gatehouses -> same route | Covered, but normally keep the same regional profile; use it for prefetch, not a visible redesign. |
| Vermilion City -> Vermilion Dock -> S.S. Anne | Safe port/ship profile change. |
| Any town/route -> building or cave; ladder/elevator between interiors | Disable the outdoor horizon or select a purpose-built interior/open-roof profile behind the fade. |
| Fly, Teleport, Dig, Escape Rope, blackout, Continue, new game, imported-save load | Resolve the destination first and initialize its profile entirely behind the existing loading/transition cover. |

## Yellow's declared surface connection graph

The following 39 undirected edges come from the checked Pokemon Yellow map
headers. They are the conservative **no hard swap** list: if the runtime
reports a crossing as `via = "connection"`, both sides must share compatible
art and use interpolation. A declared edge is not proof that every border is
walkable.

### Southwest, coast, and League

- Pallet Town <-> Route 1
- Pallet Town <-> Route 21
- Route 1 <-> Viridian City
- Viridian City <-> Route 2
- Viridian City <-> Route 22
- Route 2 <-> Pewter City
- Route 22 <-> Route 23
- Route 23 <-> Indigo Plateau
- Route 21 <-> Cinnabar Island
- Cinnabar Island <-> Route 20

### Northwest and northeast

- Pewter City <-> Route 3
- Route 3 <-> Route 4
- Route 4 <-> Cerulean City
- Cerulean City <-> Route 5
- Cerulean City <-> Route 9
- Cerulean City <-> Route 24
- Route 24 <-> Route 25
- Route 9 <-> Route 10
- Route 10 <-> Lavender Town

### Central cities

- Route 5 <-> Saffron City
- Saffron City <-> Route 6
- Saffron City <-> Route 7
- Saffron City <-> Route 8
- Route 6 <-> Vermilion City
- Route 7 <-> Celadon City
- Route 8 <-> Lavender Town

### West, east, and south loops

- Celadon City <-> Route 16
- Route 16 <-> Route 17
- Route 17 <-> Route 18
- Route 18 <-> Fuchsia City
- Vermilion City <-> Route 11
- Route 11 <-> Route 12
- Lavender Town <-> Route 12
- Route 12 <-> Route 13
- Route 13 <-> Route 14
- Route 14 <-> Route 15
- Route 15 <-> Fuchsia City
- Fuchsia City <-> Route 19
- Route 19 <-> Route 20

## Artwork families

Do not author one full panorama per map. Build a small set of compatible
families plus directional landmark cards:

| Family | Primary locations | Continuity rule |
| --- | --- | --- |
| South Kanto | Pallet, Route 1, Viridian, southern Route 2, Route 21, Route 22 | One countryside/coast base. Viridian, Forest, Cinnabar, and plateau landmarks change bearing and apparent size rather than swapping. |
| Viridian Forest | Viridian Forest | Dedicated dense enclosed horizon, selected at the gates. Gate returns restore the correct north/south South-Kanto view. |
| Northwest mountains | northern Route 2, Pewter, Routes 3/4 | Shared mountain language around Mt. Moon so neighbor rendering cannot expose an incompatible edge. |
| Cerulean highlands | Cerulean, Routes 5/9/10/24/25 | Shared foothill/river base with city, cape, cave, and power-plant cards. Blend at declared surface edges. |
| Central urban | Saffron and the inner ends of Routes 5/6/7/8 | Saffron is the largest city card. Gatehouses provide hidden selection points, but visible neighbor art must still agree at exits. |
| Western metro | Celadon, Routes 16/17/18 | Celadon card plus open west-country/Cycling Road base. Route 16-18 remains one continuous family. |
| Eastern corridor | Lavender, Vermilion, Routes 8/10/11/12/13/14/15 | Shared eastern terrain with Lavender tower, port, and coastal cards; map-border changes blend. |
| Fuchsia and south coast | Fuchsia, Routes 19/20, Cinnabar, Route 21 | Shared coastal/sea base with Fuchsia, Seafoam, volcano/island, and Pallet cards. Water horizon remains consistent across route seams. |
| Safari | Safari Zone Center/East/North/West | One dedicated family loaded at the Safari gate and retained across all four zone maps. |
| League | Route 23, Victory Road exits, Indigo Plateau | Dedicated high mountain/plateau family; gates and the cave are preferred load windows. |

Families overlap intentionally. A profile chooses a base plus a few cards; it
does not own a unique texture. This keeps the GBC/GBA voxel style consistent,
avoids visible full-sky replacements, and stays compatible with the planned
small shared atlas.

## Preload contract for Bo's rewrite

When runtime integration resumes:

1. On map entry, read `map.entered.via` and the destination map ID.
2. For `connection`, keep the current family resident, interpolate the viewer
   anchor and cards, and prewarm all declared neighbor profiles. Never perform
   synchronous image decode or GPU upload at the seam.
3. For a covered warp, select the destination profile while the transition or
   loading veil is opaque. If the destination page is unavailable, retain the
   previous neutral profile until it is ready; never reveal a black or missing
   horizon.
4. Use one shared atlas if it fits the established 2048x512 / 4 MiB target. If
   more than one page is eventually necessary, retain only current, previous,
   and declared-neighbor pages with a strict cap.
5. Do not rotate a profile to head yaw or recenter yaw. Town Map coordinates
   and live map connections define world bearings; OpenXR applies only the eye
   views.

## Provenance

- Engine behavior checked in `release-quest-v0.1.81/src/world/OverworldController.lua`:
  `crossConnection` calls `setMap(..., { seamless = true })` during the live
  step; `startWarpTo` changes maps inside `Transition`; `setMap` emits
  `map.entered` with `via = "connection"`, `"warp"`, or `"boot"`.
- Pokemon Yellow surface headers and warp targets checked from
  `pret/pokeyellow` commit
  `e6ba56989b0f2694f393e6924820be11dcc1fbb8` (2026-08-10).
- Source repository: <https://github.com/pret/pokeyellow>
- No ROM bytes, block maps, tile graphics, official sprites, saves, extracted
  caches, or commercial assets are copied into this project.

## Next art milestone

Before drawing another major card, prepare a low-detail Kanto composition
sheet that places the ten artwork families and the major directional cards at
their relative scale. Then author one transition corridor as the reference
set:

`Pallet -> Route 1 -> Viridian -> Route 2 -> Forest gates -> Viridian Forest`

That corridor exercises open connections, a covered gate transition, city and
forest scale, reciprocal bearings, coastline visibility, and the strongest
existing Quest performance baseline.
