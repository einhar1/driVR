# driVR 2.0 — Project Guidelines

## Overview

VR driving/interaction application built with **Godot 4.6** (GL Compatibility renderer) targeting **Meta Quest** via OpenXR. Uses **Jolt Physics** at 90 ticks/second.

## Architecture

```
main.tscn          → Entry point: world environment, lighting, floor, objects, player
player.tscn         → XROrigin3D with camera, left/right controllers, hands, functions, PlayerBody
addons/
  godot-xr-tools/   → VR toolkit v4.4.1-dev (hands, pickup, teleport, movement providers)
  godot_meta_toolkit/ → Meta GDExtension
  godotopenxrvendors/ → Platform-specific OpenXR loaders (Meta, Pico, etc.)
assets/textures/    → 1m×1m reference textures
```

**XR init flow**: `main.tscn` runs `start_xr.gd` → detects OpenXR/WebXR → emits `xr_started`/`xr_failed_to_initialize`.

**Player hierarchy**: XROrigin3D → Camera + Controllers (with Hands + FunctionPickup) + PlayerBody (CharacterBody3D).

**Movement providers** (in `addons/godot-xr-tools/functions/`): turn, jump, climb, grapple, flight, teleport. Base class: `XRToolsMovementProvider`.

## GDScript Conventions

- **Type hints** on all variables and function returns
- **Naming**: `snake_case` for functions/variables, `_private_prefix` for private, `p_param` for parameters, `PascalCase` for classes/enums
- **Signals** defined at top of class with typed parameters
- **`@export`** with groups and range hints; **`@onready`** for child node references
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

## Key Configuration (project.godot)

- Renderer: GL Compatibility (D3D12 on Windows, GL on mobile)
- Physics: Jolt, 90 ticks/sec
- XR: OpenXR enabled, shaders enabled
- Autoloads: `XRToolsUserSettings`, `XRToolsRumbleManager`
- VRAM: ETC2/ASTC compression enabled

## Conventions

- Don't modify files under `addons/` unless you're patching a plugin — these are managed externally.
- New VR interactions should follow the XRTools pattern: extend the appropriate base class (`XRToolsMovementProvider`, `XRToolsFunctionPickup`, etc.) and register via `is_xr_class()`.
- New scenes go in root or a domain-specific folder; textures in `assets/textures/`.
- OpenXR input bindings live in `openxr_action_map.tres` — add new actions there, not in project input map.
