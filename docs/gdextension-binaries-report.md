# GDExtension binary check report (for Discord)

Hi! I ran the addon binary checks from the project root. Here’s what I found.

## macOS paths

`addons/godot_meta_toolkit/.bin/macos`

- `template_debug/`
- `template_release/`

`addons/godot_meta_toolkit/.bin/macos/template_debug`

- `libgodot_meta_toolkit.macos.framework/`

`addons/godot_meta_toolkit/.bin/macos/template_release`

- `libgodot_meta_toolkit.macos.framework/`

`addons/godotopenxrvendors/.bin/macos`

- `template_debug/`
- `template_release/`

`addons/godotopenxrvendors/.bin/macos/template_debug`

- `libgodotopenxrvendors.macos.framework/`

`addons/godotopenxrvendors/.bin/macos/template_release`

- `libgodotopenxrvendors.macos.framework/`

Framework binaries present:

- `addons/godot_meta_toolkit/.bin/macos/template_debug/libgodot_meta_toolkit.macos.framework/libgodot_meta_toolkit.macos` (3,402,040 bytes)
- `addons/godot_meta_toolkit/.bin/macos/template_release/libgodot_meta_toolkit.macos.framework/libgodot_meta_toolkit.macos` (3,204,632 bytes)
- `addons/godotopenxrvendors/.bin/macos/template_debug/libgodotopenxrvendors.macos.framework/libgodotopenxrvendors.macos` (3,734,376 bytes)
- `addons/godotopenxrvendors/.bin/macos/template_release/libgodotopenxrvendors.macos.framework/libgodotopenxrvendors.macos` (3,519,496 bytes)

I’m on Windows, so `file` / `otool` are not available here; I couldn’t run Mach-O dependency introspection on this machine.

## Linux paths

Binaries exist:

- `addons/godot_meta_toolkit/.bin/linux/template_debug/x86_64/libgodot_meta_toolkit.so`
- `addons/godot_meta_toolkit/.bin/linux/template_release/x86_64/libgodot_meta_toolkit.so`
- `addons/godotopenxrvendors/.bin/linux/template_debug/arm64/libgodotopenxrvendors.so`
- `addons/godotopenxrvendors/.bin/linux/template_debug/x86_64/libgodotopenxrvendors.so`
- `addons/godotopenxrvendors/.bin/linux/template_release/arm64/libgodotopenxrvendors.so`
- `addons/godotopenxrvendors/.bin/linux/template_release/x86_64/libgodotopenxrvendors.so`

## Windows paths

Binaries exist:

- `addons/godot_meta_toolkit/.bin/windows/template_debug/x86_64/libgodot_meta_toolkit.dll`
- `addons/godot_meta_toolkit/.bin/windows/template_release/x86_64/libgodot_meta_toolkit.dll`
- `addons/godotopenxrvendors/.bin/windows/template_debug/x86_64/libgodotopenxrvendors.dll`
- `addons/godotopenxrvendors/.bin/windows/template_release/x86_64/libgodotopenxrvendors.dll`

## My environment

- OS: Windows 11 Home (10.0.26200)
- Architecture: x86_64 (64-bit)
- CPU: 13th Gen Intel(R) Core(TM) i5-1340P
- Godot editor version: 4.6

If useful, I can zip and share these folders:

- `addons/godot_meta_toolkit/.bin`
- `addons/godotopenxrvendors/.bin`

My guess is the crash is likely architecture/runtime mismatch on macOS (Intel vs Apple Silicon / missing universal slice). Running `file` + `otool -L` on the Mac machine should confirm that quickly.
