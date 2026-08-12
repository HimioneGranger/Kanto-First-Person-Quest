# Kanto in First Person — Quest Port

This is the dedicated standalone Meta Quest maintenance fork of **Kanto in
First Person**, originally created by **briddsy / mrmushrooms11**.

## Baseline and branch policy

- Upstream repository: `https://github.com/mrmushrooms11/kanto-first-person`
- Upstream Git baseline: `94d0151`, tagged `firstperson1.60.0`
- Official 1.60.0 release-package source SHA-256:
  `B54B28271918AAAB9A11CED66247898E51CFF5E5F03D3530FF3B81BB3B25AF29`
- Quest development branch: `quest-vr`
- Quest release identity begins at `1.60.0-quest.1`.

The upstream tag's checked-in manifest still identifies `1.57.2`. Commit
`8dddb2b` records a separate, reviewable synchronization from the creator's
official 1.60.0 release package before Quest-specific work begins.

## Scope

The fork will isolate Quest-specific compatibility and performance changes
without deleting working desktop behavior. Intended work includes measured
render-cost reduction, VR camera compatibility, lifecycle-safe resources, and
integration with the separately installed Dramaless Quest fork.

No speculative renderer rewrite is part of the fork baseline. Each quality
reduction must be optional or Quest-detected, measurable on physical hardware,
and must not silently reduce desktop or Quest 3 output.

## Distribution boundary

This repository and its packages must not contain Pokémon ROMs, saves,
ROM-derived caches, generated commercial artwork, credentials, or APKs. The
normal Gen1Recomp legal ROM-import workflow remains unchanged.

The original repository does not contain a general-purpose license file. The
maintainer has direct creator permission for this credited Quest adaptation;
see `PERMISSION.md`. That permission does not grant rights over material owned
by unrelated third parties.
