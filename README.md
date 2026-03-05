# driVR

`driVR` is a work in progress Godot XR prototype.

- Engine: Godot 4.6 (project feature tag: `4.6`)
- Main scene: `res://Game.tscn`
- XR: OpenXR is enabled in project settings

## Export notes (Meta Quest 2)

This repo already contains an Android export preset named **"META Quest 2"**.

Before exporting, verify:

- Android export templates are installed in Godot.
- Your Android SDK/JDK setup is configured in the Godot editor settings.
- A valid Android signing keystore is configured (the preset has signing enabled).
- `package/unique_name` is set appropriately (currently `com.einar.driVR`).

Then export using the Android preset to generate an APK/AAB for headset deployment.

## Credits

This project uses **"Lopwoly rigged hand in PSX/PS1 style"** by **Alexander Snitko**.

- Source: <https://sketchfab.com/3d-models/lopwoly-rigged-hand-in-psxps1-style-8e89510d963a4d6f99e863bd2742ab01>
- Creator profile: <https://sketchfab.com/alexandersnitko>
- License: Creative Commons Attribution 4.0 International (CC BY 4.0) — <https://creativecommons.org/licenses/by/4.0/>
- Changes: Used in this project as a hand asset for VR gameplay.
