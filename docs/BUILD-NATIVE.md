# Building native GDExtension binaries (macOS)

High-level steps to build a native `.framework` for an addon on macOS.

Prerequisites:
- Xcode and Xcode Command Line Tools installed.
- Python, SCons, and the Godot `godot-cpp` bindings (or the addon-provided build scripts).

Steps:

1. Clone or obtain the native addon source (C++ files and `SConstruct` / build scripts).

2. Build the `godot-cpp` bindings (if required) following the addon README or Godot CPP instructions.

3. Run the addon's build script. Example (addon uses SCons):

```bash
# from the addon's native source folder
scons platform=macos arch=universal target=release
```

4. Locate the produced binary (e.g., `lib<name>.macos.framework`) and place it in the addon `.bin` path expected by the `.gdextension` manifest. Example layout:

```
addons/<addon>/.bin/macos/template_release/lib<name>.macos.framework
```

5. Restore the `.gdextension` manifest on your local debug branch and launch Godot.

Notes:
- Building native addons may require adjusting `SConstruct` flags, SDK paths, or using `arch=arm64` for Apple Silicon.
- If you prefer, you can request prebuilt binaries from the addon upstream or from a teammate who built them on macOS.
