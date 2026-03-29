# driVR 2.0 — Project Guidelines

## Overview

This repository is a Godot 4.6 VR driving-theory app for Meta Quest. The player sits inside a persistent car, answers quiz questions on an in-car panel, and each question can swap in its own 3D scenario scene.

## Architecture

- Entry scene: `scenes/main.tscn`
- XR startup and seat alignment: `scripts/xr/start_xr_with_spawn_alignment.gd`
- Player rig: `scenes/components/player.tscn`
- In-car quiz UI: `scenes/components/test_panel.tscn` with controller logic in `scripts/test_panel_controller.gd`
- Quiz flow is deliberately decoupled:
  - `scripts/question_manager.gd` owns question state and emits signals
  - `scripts/question_scene_runner.gd` loads and unloads per-question scenes and repositions the persistent car
  - `scripts/test_panel_controller.gd` renders the question UI and reacts to quiz signals
- Question content lives in `resources/` via `QuestionData` and `QuestionBank` resources
- `road_demos/` documents road-generator patterns but is not part of the main gameplay loop

The `XROrigin3D` is a child of `car/DriversSeatAnchor`, not a root-level node. Preserve that relationship when changing player spawning or seat alignment.

## Code Style

- Follow `.github/instructions/gdscript.instructions.md` for all `*.gd` changes
- Follow `.github/instructions/tscn.instructions.md` for all `*.tscn` changes
- Use typed GDScript, `p_`-prefixed parameters, `##` doc comments, and `%UniqueName` `@onready` lookups where possible
- Prefer existing scene/signal patterns over introducing tightly coupled cross-node lookups

## Build and Validate

- Run the project from the editor with `scenes/main.tscn`
- Export target: `Meta Quest`
- Android/export, ADB deploy, and logcat workflows are documented in `README.md`
- Road-generator implementation details and examples are documented in `road_demos/README.md`

## Conventions

- Do not edit `addons/` unless you are intentionally patching a third-party plugin
- Add new OpenXR bindings in `openxr_action_map.tres`, not in the Godot project input map
- New scenario scenes belong in `scenes/scenarios/` and should expose a root-level `SpawnPoint` for car placement
- UI scripts running inside `Viewport2Din3D` should resolve gameplay nodes through `get_tree().current_scene`, not `get_tree().root.get_child(0)`
- New VR interactions should build on XR Tools base classes instead of bypassing the addon architecture

## Agent-Critical Pitfalls

- Physics/world changes around question swaps must be deferred; modifying physics objects synchronously during a physics step can crash Jolt. Follow the deferred loading pattern already used in `scripts/question_scene_runner.gd`.
- If road visuals exist but AI driving cannot find lanes, check that each `RoadContainer` has `generate_ai_lanes = true`.
- Physics layer and mask mismatches are a common cause of broken VR interaction. Be conservative when changing collision settings.
- Desktop fallback is intentional: if XR is unavailable, `start_xr_with_spawn_alignment.gd` adds `scripts/desktop_debug.gd` for headset-free testing.
