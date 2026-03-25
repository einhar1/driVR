# driVR 2.0 — Project Guidelines

## Overview

VR driving-theory quiz app built with **Godot 4.6** (GL Compatibility) targeting **Meta Quest** via OpenXR. Uses **Jolt Physics** at 90 ticks/second. The player sits inside an auto-driving car while answering quiz questions shown on an in-car panel; each question can load its own 3D scenario scene.

## Architecture

```
scenes/main.tscn      → Entry point: environment, car (with player inside), quiz system
scenes/player.tscn    → XROrigin3D with camera, left/right hand controllers, pointer
scenes/test_panel.tscn→ 2D quiz UI rendered in-world via Viewport2Din3D
scenes/scenarios/     → Per-question 3D environments (loaded dynamically)
cars/                 → VehicleBody3D car + autonomous lane-following driver
scripts/              → Quiz logic, auto-driver, UI controller, XR startup
resources/            → QuestionData/QuestionBank resources (.tres)
road_demos/           → Road-generator demo scenes (not part of main app)
addons/
  godot-xr-tools/    → VR toolkit v4.4.1-dev (hands, pointer, movement providers)
  godot_meta_toolkit/ → Meta GDExtension
  godotopenxrvendors/ → Platform-specific OpenXR loaders
  road-generator/     → Road/highway mesh generator v0.9.0
  godot_mcp/          → MCP editor plugin
```

### XR Init Flow

`main.tscn` runs `start_xr_with_spawn_alignment.gd` → initializes OpenXR → samples HMD position over several frames → aligns XROrigin3D to the car's driver-seat anchor so the headset matches the authored seat pose.

### Main Scene Tree (`main.tscn`)

```
Main (Node3D) [start_xr_with_spawn_alignment.gd]
├── WorldEnvironment (ProceduralSkyMaterial)
├── DirectionalLight3D
├── car (Doge.tscn — VehicleBody3D)
│   ├── DriversSeatAnchor
│   │   └── XROrigin3D (player.tscn instance)
│   ├── RoadLaneAgent
│   ├── AutoDriver [car_auto_driver.gd]
│   └── Viewport2Din3D (renders test_panel.tscn)
├── QuestionManager [question_manager.gd]
├── QuestionSceneRunner [question_scene_runner.gd]
└── DefaultEnvironment (Floor, RoadManager — hidden during question scenes)
```

**Key**: XROrigin3D is a child of `car/DriversSeatAnchor`, not a root-level node. The player sees the world from inside the car.

### Player Hierarchy (`player.tscn`)

```
XROrigin3D
├── XRCamera3D (Y=1.7m)
│   └── VRCommonShaderCache
├── XRController3D_left
│   └── LeftHand (XRTools hand model)
├── XRController3D_right
│   ├── RightHand (XRTools hand model)
│   └── FunctionPointer (laser_length=1m)
```

### Quiz System

Signal-driven architecture with three decoupled components:

1. **QuestionManager** (`scripts/question_manager.gd`) — State machine. Holds `QuestionBank`, tracks current index, validates answers. Emits `question_changed`, `answer_validated`, `question_change_requested`.
2. **QuestionSceneRunner** (`scripts/question_scene_runner.gd`) — Listens to `question_change_requested`. Loads/unloads per-question `.tscn` scenes, hides `DefaultEnvironment`, places the car at the scene's `SpawnPoint`.
3. **test_panel_controller** (`scripts/test_panel_controller.gd`) — 2D UI inside `Viewport2Din3D`. Displays question text + answer buttons. Listens to QuestionManager signals.

Data: `QuestionData` (Resource) stores question text, options, correct index, optional `scene_path`, and `spawn_point_path`. `QuestionBank` holds an array of `QuestionData`.

### Car & Auto-Driver

- `BaseCar.gd` — `VehicleBody3D` controller. Keyboard/gamepad input or autonomous mode via `AutoDriver`.
- `car_auto_driver.gd` — Lane-following using `RoadLaneAgent` (addon). Configurable lookahead, steering gain, speed limits. Auto lane-switching. Emits `auto_drive_completed`.
- `CameraFollow.gd` — Third-person follow cam (used outside VR / debug).

### Road Generator

Addon (`addons/road-generator/`). Key nodes: `RoadContainer`, `RoadPoint`, `RoadLane`, `RoadIntersection`, `RoadLaneAgent`. Demo scenes in `road_demos/` show procedural generation, AStar pathfinding, and AI traffic with actor pooling — see `road_demos/README.md`.

## GDScript Conventions

See `.github/instructions/gdscript.instructions.md` for full rules. Key points: mandatory type hints, `p_param` parameter prefix, `##` doc comments, `@onready` with `%` unique names, signals at top of class.

## Physics Layers

```
1=Static World  2=Dynamic World  3=Pickable Objects  4=Wall Walking  5=Grappling Target
17=Held Objects  18=Player Hands  19=Grab Handles  20=Player Body
21=Pointable Objects  22=Hand Pose Areas  23=UI Objects
```

Mismatched layers/masks are a common source of interaction bugs.

## Build & Run

- **Editor**: F5 to run, or export via Project → Export
- **CLI export**: `godot --export-debug "Meta Quest"`
- **Android build**: `./gradlew assembleDebug` from `android/build/`
- **Deploy/logs**: See `README.md` for ADB deploy and logcat commands
- **Package ID**: `com.einar.driVR`

Quest 2/3/Pro (arm64-v8a). Enabled: eye/face/body/hand tracking, passthrough, render model.

## Key Configuration (project.godot)

- Renderer: GL Compatibility (D3D12 on Windows, GL on mobile)
- Physics: Jolt, 90 ticks/sec
- XR: OpenXR enabled, shaders enabled
- Autoloads: `XRToolsUserSettings`, `XRToolsRumbleManager`
- Editor plugins: `godot-xr-tools`, `road-generator`, `godot_mcp`
- VRAM: ETC2/ASTC compression enabled

## Conventions

- Don't modify files under `addons/` unless patching a plugin — these are managed externally.
- New VR interactions should extend XRTools base classes (`XRToolsMovementProvider`, etc.) and register via `is_xr_class()`.
- New scenes go in `scenes/` or a domain-specific folder; textures in `assets/textures/`.
- OpenXR input bindings live in `openxr_action_map.tres` — add new actions there, not in the project input map.
- Road features use `RoadContainer` + `RoadPoint`; AI vehicles use `RoadLaneAgent` for lane following.
- For procedural road content, follow `road_demos/procedural_generator/` — distance-cull RoadPoints and pool actors.
- UI scripts inside `Viewport2Din3D` must resolve gameplay nodes via `get_tree().current_scene`, not `get_tree().root.get_child(0)` (autoloads may be first children).
- Per-question scenario scenes must include a `SpawnPoint` node at root level for car placement.
