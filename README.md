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

## Export notes (Meta Quest 2)

This repo already contains an Android export preset named **"META Quest 2"**.

Before exporting, verify:

- Android export templates are installed in Godot.
- Your Android SDK/JDK setup is configured in the Godot editor settings.
- A valid Android signing keystore is configured (the preset has signing enabled).
- `package/unique_name` is set appropriately (currently `com.einar.driVR`).

Then export using the Android preset to generate an APK/AAB for headset deployment.

## Deploy over USB cable (Meta Quest 2)

Use this for first-time setup and the most stable/fast installs.

- Enable Developer Mode for your Quest 2.
- Connect Quest 2 to your PC via USB-C.
- Put on the headset and accept the USB debugging prompt.
- Verify connection:
  - `adb devices`

When the headset appears in the device list, deploy from Godot using the **"META Quest 2"** preset.

## Wireless deploy (Meta Quest 2)

You can deploy wirelessly after one-time USB debugging authorization.

- Complete the USB setup above at least once.
- Switch ADB to TCP mode, then connect over Wi-Fi:
  - `adb tcpip 5555`
  - `adb connect <QUEST_IP>:5555`
- Verify wireless connection:
  - `adb devices`

You can then deploy from Godot to the Quest without a cable (both devices must be on the same LAN).

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

```
main.tscn              → Entry point: world environment, lighting, floor, XROrigin3D, road manager
player.tscn            → XROrigin3D with camera, controllers, hands, movement providers
road_demos/            → Demo scenes for road generation, navigation, traffic simulation
addons/
  godot-xr-tools/      → VR toolkit for hand interactions, movement, teleport
  godot-meta-toolkit/  → Meta platform support
  road-generator/      → Procedural road/highway generation utilities
assets/textures/       → Reference 1m×1m textures for sizing
```

## GDScript Conventions

- Type hints on all variables and function returns
- `snake_case` for functions/variables, `PascalCase` for classes/enums
- `@export` with groups; `@onready` for child node references
- `##` doc comments (Godot docstring format)
- Physics layers 1–23 are configured; see `project.godot` for layer assignments
