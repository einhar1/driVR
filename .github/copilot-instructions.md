# driVR 2.0 — Project Guidelines

## Overview

VR driving/interaction application built with **Godot 4.6** (GL Compatibility renderer) targeting **Meta Quest** via OpenXR. Uses **Jolt Physics** at 90 ticks/second. Features road generation, VR hand interaction, and traffic simulation.

## Architecture

```
main.tscn            → Entry point: world environment, lighting, floor, objects, player, road manager
player.tscn          → XROrigin3D with camera, left/right controllers, hands, functions, PlayerBody
test_panel.tscn      → Minimal 2D UI test (rendered in-world via Viewport2Din3D)
road_demos/          → Road generator demo scenes (menu, intersections, navigation, procedural gen)
addons/
  godot-xr-tools/    → VR toolkit v4.4.1-dev (hands, pickup, teleport, movement providers)
  godot_meta_toolkit/ → Meta GDExtension
  godotopenxrvendors/ → Platform-specific OpenXR loaders (Meta, Pico, etc.)
  road-generator/    → Road/highway mesh generator v0.9.0 (RoadContainer, RoadPoint, RoadLane, RoadIntersection)
assets/textures/     → 1m×1m reference textures
```

### XR Init Flow

`main.tscn` runs `start_xr.gd` → detects OpenXR/WebXR → emits `xr_started`/`xr_failed_to_initialize`.

### Main Scene Tree (`main.tscn`)

```
Main (Node3D) [start_xr.gd]
├── WorldEnvironment (ProceduralSkyMaterial)
├── DirectionalLight3D (shadow_enabled)
├── Floor (StaticBody3D, layer=1)
├── Table (StaticBody3D, layer=1)
├── PickableObject (XRTools pickable, layer=3)
├── XROrigin3D (player.tscn instance)
├── Viewport2Din3D (renders test_panel.tscn)
└── RoadManager (road_manager.gd)
```

### Player Hierarchy (`player.tscn`)

```
XROrigin3D
├── XRCamera3D (Y=1.7m) [VRCommonShaderCache, Vignette]
├── XRController3D_left
│   ├── LeftHand → FunctionPickup
│   ├── FunctionTeleport
│   └── MovementDirect
├── XRController3D_right
│   ├── RightHand → FunctionPickup
│   ├── MovementTurn
│   └── FunctionPointer (laser_length=1)
└── PlayerBody (CharacterBody3D)
```

Asymmetric controller setup: left = direct movement + teleport, right = turning + pointer. Both hands have pickup.

### Road Generator

Addon (`addons/road-generator/`) generates 3D highway meshes with dynamic lane counts. Key nodes: `RoadContainer`, `RoadPoint`, `RoadSegment`, `RoadLane`, `RoadIntersection`, `RoadLaneAgent`. Demo scenes in `road_demos/` show procedural generation, AStar pathfinding over lanes, and AI traffic spawning with actor pooling.

**Movement providers** (in `addons/godot-xr-tools/functions/`): turn, jump, climb, grapple, flight, teleport. Base class: `XRToolsMovementProvider`.

## GDScript Conventions

- **Type hints** on all variables and function returns
- **Naming**: `snake_case` for functions/variables, `_private_prefix` for private, `p_param` for parameters, `PascalCase` for classes/enums
- **Signals** defined at top of class with typed parameters
- **`@export`** with groups and range hints; **`@onready`** for child node references (prefer `%` unique name notation)
- **`##` doc comments** (Godot docstring format)
- **`@tool`** + `@icon()` for editor-visible scripts
- XRTools uses `is_xr_class(name: String) -> bool` for inheritance checking

## Physics Layers

```
1=Static World  2=Dynamic World  3=Pickable Objects  4=Wall Walking  5=Grappling Target
17=Held Objects  18=Player Hands  19=Grab Handles  20=Player Body
21=Pointable Objects  22=Hand Pose Areas  23=UI Objects
```

Assign collision layers/masks carefully — mismatched layers are a common source of interaction bugs.

## Build & Run

- **Editor**: F5 to run, or export via Project → Export
- **CLI export**: `godot --export-debug "Meta Quest"`
- **Android build**: `./gradlew assembleDebug` from `android/build/`
- **Package ID**: `com.einar.driVR`

### Quest Export Features

arm64-v8a only. Enabled: eye tracking, face tracking, body tracking, hand tracking, passthrough, render model. Supports Quest 2/3/Pro (Quest 1 disabled).

## Key Configuration (project.godot)

- Renderer: GL Compatibility (D3D12 on Windows, GL on mobile)
- Physics: Jolt, 90 ticks/sec
- XR: OpenXR enabled, shaders enabled
- Autoloads: `XRToolsUserSettings`, `XRToolsRumbleManager`
- Editor plugins: `godot-xr-tools`, `road-generator`
- VRAM: ETC2/ASTC compression enabled

## Conventions

- Don't modify files under `addons/` unless you're patching a plugin — these are managed externally.
- New VR interactions should follow the XRTools pattern: extend the appropriate base class (`XRToolsMovementProvider`, `XRToolsFunctionPickup`, etc.) and register via `is_xr_class()`.
- New scenes go in root or a domain-specific folder; textures in `assets/textures/`.
- OpenXR input bindings live in `openxr_action_map.tres` — add new actions there, not in project input map.
- Road features use `RoadContainer` + `RoadPoint` nodes; AI vehicles depend on `RoadLaneAgent` for lane following.
- For procedural road content, follow the pattern in `road_demos/procedural_generator/` — distance-cull RoadPoints and pool actors for performance.
