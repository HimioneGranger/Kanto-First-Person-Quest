# Location-aware horizon migration

New location-aware horizon artwork and development have moved to the standalone
**Kanto World Horizons** project:

<https://github.com/HimioneGranger/Kanto-World-Horizons>

Kanto in First Person retains its four legacy painted panoramas and the
disabled q9 `WORLD HORIZON BETA` implementation only as a temporary rollback
and compatibility reference. That prototype is frozen here. Do not add new
horizon artwork, profiles, or behavior to this repository.

The new project owns:

- original horizon concepts and their source manifest;
- location/map profiles and landmark bearings;
- horizon transition rules and bounded atlas policy;
- the future Dramaless provider adapter;
- optional KFP compatibility through public interfaces only.

KFP continues to own first-person presentation, interiors, walls, ceilings,
and its other existing effects. Once the standalone adapter is physically
validated, removal of the frozen q9 option from KFP should be a separate,
reviewed change—not part of Bo's rewrite merge.
