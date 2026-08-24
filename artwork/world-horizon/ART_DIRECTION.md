# Kanto world-horizon art direction

Map-boundary and hidden-load rules are defined in
[`MAP_TRANSITION_PLAN.md`](MAP_TRANSITION_PLAN.md). In short: open route borders
share continuous art, while doors, gates, caves, and covered travel may select
a substantially different horizon profile.

## Status and boundary

This folder is artwork-only while the Kanto rewrite from Bo is pending. None
of these concepts is consumed by `main.lua`, Dramaless, the Quest APK, or the
q8 rollback package. The q9 runtime prototype is evidence, not the integration
target.

The physical Quest screenshot retained locally under the workspace's
`artifacts/world-horizon-art/` folder shows two separate problems. It is test
evidence and is intentionally not committed or packaged:

- checkerboard sky, missing geometry, and unrelated scene breakage are runtime
  regressions and are out of scope here;
- the old repeating city panorama reads as a nearby wall, while the new forest
  card reads as a small decoration at its base. That is an art-scale mismatch.

The new system must never mix a full repeating panorama with normalized
location cards. Every distant subject will be authored as a transparent card
using one shared scale language.

## Shared scale language

The reference master is a transparent 2048x512 canvas with a common baseline.
The values below describe visible silhouette height before any later distance
scaling. They are art-direction targets, not renderer constants.

| Class | Examples | Height target | Forest-relative height |
| --- | --- | ---: | ---: |
| Regional natural mass | Viridian Forest | 260-320 px | 1.00 |
| Mountain mass | Mt. Moon, Indigo Plateau | 220-290 px | 0.85 |
| Major city | Saffron, Celadon | 155-200 px | 0.55-0.65 |
| Small city/town | Pewter, Cerulean, Pallet | 95-145 px | 0.35-0.45 |
| Single landmark | Pokemon Tower, Power Plant | 130-220 px peak | contextual |
| Coast/sea edge | Routes 19-21 | 40-90 px | 0.15-0.30 |

Saffron can have the tallest man-made peak, but its overall skyline must remain
lower than the Viridian Forest canopy at equal display scale. Width and density
communicate that it is the largest city; raw vertical size does not.

## Composition rules

- Transparent sky only. Never bake a sky color, clouds, fog, or checkerboard
  into a landmark.
- One non-repeating location silhouette per asset.
- Crisp GBC/GBA pixel clusters with subtle block/voxel depth; no smooth painted
  antialiasing or neon edge halos.
- Broad, irregular silhouettes. Avoid long repeated vertical seams in tree
  canopies and repeated building blocks.
- Keep the bottom edge simple enough to disappear behind real terrain.
- No text, logos, signs, characters, or UI.
- Art masters remain independent of Town Map coordinates and runtime distance.
  Bo's rewrite can later decide the provider/API contract without requiring the
  artwork to be regenerated.

## Directional continuity plan

The final provider should select cards by direction, but the art itself stays
reusable and renderer-agnostic:

- Pallet/Route 1: Viridian/forest mass north; coast and Cinnabar cues south.
- Viridian/Route 2: forest and Pewter cues north; Pallet lowlands south;
  Indigo Plateau mountains west.
- Routes 3-4: Mt. Moon west and Cerulean low skyline east.
- Routes 5-8: Saffron toward the center; Celadon west; Lavender Tower east.
- Routes 11-12: Vermilion/coast south-west; Lavender Tower north.
- Routes 16-18: Celadon north-east; Fuchsia/woodland south-east.
- Routes 19-21: sea dominates; Fuchsia, Seafoam, Cinnabar, and Pallet appear
  only in their corresponding bearings.
- Routes 22-23: Victory Road and Indigo Plateau are the dominant western mass.

## Concept inventory

- `concepts/saffron-city-major-card-v1.png`: first major-city scale anchor.
  The source has extra transparent headroom; when normalized to the shared
  2048x512 master, its skyline is intended to occupy about 60 percent of the
  approved forest silhouette height.
- Existing `horizon-atlas.png`: current Viridian Forest visual reference. It is
  not the final atlas layout.

## Production order

1. Lock scale with Viridian Forest, Saffron, Pallet, Mt. Moon, and Lavender
   Tower concept cards.
2. Produce the remaining city/town silhouettes using those anchors.
3. Produce coast, island, mountain, and cave-mouth transition cards.
4. Check adjacent-route continuity on a static compass board.
5. Only after Bo's rewrite lands, adapt the approved cards to its provider and
   texture-budget contract.
