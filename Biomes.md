# Biomes

This document lists every currently implemented planet biome and what makes each one distinct in gameplay and presentation.

## Biome List

### 1) Asteroid Rubble
- **Theme:** fractured rock world with debris fields.
- **Typical size:** leans `Tiny` to `Medium`.
- **Typical gravity:** leans `Micro-G` / `Low-G`.
- **Terrain profile:** very rough macro terrain with strong ridge variation.
- **Ore tendency:** usually `Patchy` to `Rich`.
- **Alien tendency:** usually `Low` to `Heavy` (mid range).
- **Unique prop mix:** `rock_cluster`, `crater_decal`, `salvage_heap`.
- **Surface identity:** rocky gray-brown checkerboard palette.

### 2) Cratered Moon
- **Theme:** dusty impact-scarred moon.
- **Typical size:** mostly `Small` to `Large`.
- **Typical gravity:** balanced around `Low-G` / `Earthlike`.
- **Terrain profile:** moderate craters and ridges; less jagged than asteroid rubble.
- **Ore tendency:** usually `Patchy` to `Rich`.
- **Alien tendency:** usually `Low` to `Heavy` (mid range).
- **Unique prop mix:** `crater_decal`, `rock_cluster`, `ruin_pillar`.
- **Surface identity:** neutral lunar checkerboard palette.

### 3) Metallic Core
- **Theme:** dense iron-rich world.
- **Typical size:** mostly `Small` to `Large`.
- **Typical gravity:** biased to `Earthlike` / `Heavy-G` / `Crushing`.
- **Terrain profile:** cleaner macro forms with moderate relief.
- **Ore tendency:** strongly `Standard` to `Bonanza`.
- **Alien tendency:** usually `Low` to `Heavy` (mid range).
- **Unique prop mix:** `metal_spire`, `crystal`, `salvage_heap`.
- **Surface identity:** steel-toned checkerboard palette.

### 4) Volcanic Shard
- **Theme:** unstable volcanic high-relief world.
- **Typical size:** mostly `Small` to `Large`.
- **Typical gravity:** usually `Low-G` to `Heavy-G`.
- **Terrain profile:** high macro + ridge values; sharp dramatic elevations.
- **Ore tendency:** usually `Patchy` to `Rich`.
- **Alien tendency:** high threat, often `Moderate` to `Overwhelming`.
- **Unique prop mix:** `basalt_column`, `lava_vent`, `crystal`.
- **Surface identity:** hot orange-red checkerboard palette.

### 5) Ice Dustball
- **Theme:** frozen wind-worn ice sphere.
- **Typical size:** mostly `Small` to `Large`.
- **Typical gravity:** balanced around `Low-G` / `Earthlike`.
- **Terrain profile:** smoother lower-amplitude terrain.
- **Ore tendency:** often lower (`Scarce` to `Standard`).
- **Alien tendency:** usually `Low` to `Heavy` (mid range).
- **Unique prop mix:** `ice_spike`, `crystal`, `rock_cluster`.
- **Surface identity:** cold blue-white checkerboard palette.

### 6) Habitable World
- **Theme:** greener, calmer surface with natural growth.
- **Typical size:** biased larger (`Medium` / `Large` / `Huge`).
- **Typical gravity:** around `Earthlike` with moderate variation.
- **Terrain profile:** moderate rolling terrain, readable traversal.
- **Ore tendency:** usually `Patchy` to `Rich`.
- **Alien tendency:** usually `Low` to `Heavy` (less extreme than volcanic/swamp).
- **Unique prop mix:** `tree`, `ruin_pillar`, `rock_cluster`.
- **Surface identity:** green-brown checkerboard palette.

### 7) Desert Dune
- **Theme:** arid sandy world with sparse structures.
- **Typical size:** `Small` to `Large`.
- **Typical gravity:** mostly `Low-G` / `Earthlike` / `Heavy-G`.
- **Terrain profile:** broad dune-like forms, lower ridge intensity.
- **Ore tendency:** usually `Patchy` to `Standard`, sometimes `Rich`.
- **Alien tendency:** usually `Low` to `Heavy` (mid range).
- **Unique prop mix:** `dune_grass`, `ruin_pillar`, `rock_cluster`.
- **Surface identity:** warm tan checkerboard palette.

### 8) Toxic Swamp
- **Theme:** hazardous bioactive surface.
- **Typical size:** biased to `Medium` / `Large`.
- **Typical gravity:** tends heavier (`Earthlike` to `Crushing`).
- **Terrain profile:** uneven heavy organic relief with extra detail.
- **Ore tendency:** often high (`Standard` to `Bonanza`).
- **Alien tendency:** high threat, often `Moderate` to `Overwhelming`.
- **Unique prop mix:** `fungal_bloom`, `toxic_pod`, `ruin_pillar`.
- **Surface identity:** saturated green checkerboard palette.

## Global Biome Rules (Current Build)

- **Gravity bounds are clamped by class mapping:**
  - minimum `0.5x` (Micro-G)
  - maximum `2.0x` (Crushing)
- **All gameplay-critical spawn placement** (rover/enemies/powerups/ore/props) uses surface raycasts rather than raw radius placement.
- **Spawn offsets by category:**
  - Rover/enemies: larger offset so they drop to terrain and avoid clipping.
  - Props/collectables: near-ground offset so they sit on terrain.
- **Planet textures are currently temporary checkerboards** (triplanar) for scale/readability tuning.
