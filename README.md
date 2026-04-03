# driVR 2.0

VR driving/interaction application built with **Godot 4.6** targeting **Meta Quest** via OpenXR.

## Project Setup

- **Engine**: Godot 4.6 (GL Compatibility renderer)
- **Main scene**: `res://main.tscn`
- **XR**: OpenXR enabled; uses Jolt Physics at 90 ticks/second
- **Renderer**: GL Compatibility (D3D12 on Windows, GL on mobile)
- **Key features**: Road generation, VR hand interaction, traffic simulation, procedural road generation

### Core Dependencies

- `godot-xr-tools` (v4.4.1-dev) – VR toolkit with hand interactions, pickup, teleport, movement providers
- `godot-meta-toolkit` – Meta GDExtension for Quest
- `godotopenxrvendors` – OpenXR loaders (Meta, Pico, etc.)
- `road-generator` (v0.9.0) – Procedural highway/intersection mesh generation

## Export to Meta Quest

This repo already includes an Android export preset named **`Meta Quest`**.

For a first-time setup:

1. Install **Godot 4.6** with Android export templates.
1. Install the **Android SDK** and a **Java JDK**, then point Godot to them in **Editor Settings → Export → Android**.
1. Open this project in Godot and make sure it loads without missing dependencies.
1. Confirm the Android package name is suitable for your device/builds.

   Current value: `com.einar.driVR`

1. Configure signing in Godot.
   - For local testing, a debug keystore is enough.
   - For distribution, use your own release keystore.

1. In **Project → Export**, select **`Meta Quest`** and export an **APK** for headset testing.

Project-specific export details:

- Target architecture: `arm64-v8a`
- XR mode: enabled
- Meta plugin: enabled
- Quest support: Quest 2, Quest 3, and Quest Pro
- Optional Meta features already enabled in the preset: eye tracking, face tracking, body tracking, hand tracking, passthrough, render model

If export fails, the usual culprits are missing Android templates, incorrect SDK/JDK paths, or signing not being configured.

### Local developer overrides (`dev.local.cfg`)

For machine-specific values that should not be committed, use `dev.local.cfg`.

- Copy `dev.local.cfg.example` to `dev.local.cfg` (gitignored).
- `scripts/question_manager.gd` reads:
  - `[debug] run_single_question`
  - `[debug] question_index`

## Deploy over USB (recommended first run)

Use USB for the first install and for the least fiddly workflow.

- Enable **Developer Mode** for your Quest headset in the Meta mobile app.
- Connect the headset to your PC with USB-C.
- Put on the headset and accept the USB debugging prompt.
- Verify connection:
  - `adb devices`

When the headset appears in the device list, export or deploy using the **`Meta Quest`** preset.

## Wireless deploy

You can deploy wirelessly after one-time USB debugging authorization.

- Complete the USB setup above at least once.
- Switch ADB to TCP mode, then connect over Wi-Fi:
  - `adb tcpip 5555`
  - `adb connect <QUEST_IP>:5555`
- Verify wireless connection:
  - `adb devices`

You can then deploy from Godot without a cable, as long as the PC and headset are on the same network.

## Android logging (adb logcat variants)

Common options for different log output formats:

- Godot-only logs (quiet everything else):
  - `adb logcat -s godot:V Godot:V *:S`
- Godot-only logs with timestamps:
  - `adb logcat -v time -s godot:V Godot:V *:S`
- Godot-only logs with thread/process details:
  - `adb logcat -v threadtime -s godot:V Godot:V *:S`
- Warning/error logs from all tags, but keep Godot verbose:
  - `adb logcat *:W godot:V Godot:V`
- Full device logs (all tags):
  - `adb logcat`
- Crash buffer only:
  - `adb logcat -b crash`
- Dump current logs once and exit (good for sharing):
  - `adb logcat -d`
- Clear log buffers:
  - `adb logcat -c`

## Project Structure

```text
main.tscn              → Entry point: world environment, lighting, floor, XROrigin3D, road manager
player.tscn            → XROrigin3D with camera, controllers, hands, movement providers
road_demos/            → Demo scenes for road generation, navigation, traffic simulation
addons/
  godot-xr-tools/      → VR toolkit for hand interactions, movement, teleport
  godot-meta-toolkit/  → Meta platform support
  road-generator/      → Procedural road/highway generation utilities
assets/textures/       → Reference 1m×1m textures for sizing
resources/             → QuestionData resources and question bank
scenes/
  main.tscn            → Entry scene
  components/          → Player rig, test panels, UI components
  scenarios/           → Question-specific 3D scenes
```

## Quiz Architecture

The quiz system decouples question management, scene loading, and UI rendering:

- **QuestionManager** (`scripts/question_manager.gd`) – owns question state, emits signals, inits via `dev.local.cfg`
- **QuestionSceneRunner** (`scripts/question_scene_runner.gd`) – loads per-question scenes, repositions persistent car, manages environment visibility
- **test_panel_controller.gd** – renders quiz UI, handles answer input, reacts to quiz signals
- **StartEndScreenController** – shows start/end screens in a dedicated viewport
- **QuestionDriveScenario** – typed contract for scenario scripts providing auto-drive behavior

### Manager initialization pattern

All quiz controllers resolve `QuestionManager` via group `"question_manager"` and wait for `manager_initialized` signal:

```gdscript
var manager: QuestionManager = get_tree().get_first_node_in_group("question_manager")
if manager.question_bank != null:
    # Already initialized
    _setup()
else:
    # Wait for initialization
    await manager.manager_initialized
    _setup()
```

This pattern ensures correct timing in debug single-question mode where the quiz is already active during `_ready()`.

---

## GDScript Conventions

- Type hints on all variables and function returns
- `snake_case` for functions/variables, `PascalCase` for classes/enums
- `@export` with groups; `@onready` for child node references
- `##` doc comments (Godot docstring format)
- Physics layers 1–23 are configured; see `project.godot` for layer assignments
