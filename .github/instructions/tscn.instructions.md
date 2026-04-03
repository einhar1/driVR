---
description: "Use when creating or editing Godot scene files (.tscn). Enforces driVR scene structure, XR seat hierarchy, scenario SpawnPoint requirements, and safe scene-editing conventions."
applyTo: "**/*.tscn"
---

# Godot Scene Conventions (.tscn)

## Scope

These rules apply to Godot scene files in this repository.
For script style, follow `.github/instructions/gdscript.instructions.md`.

## Preserve Critical Hierarchies

- Keep `XROrigin3D` parented under `car/DriversSeatAnchor` in the gameplay flow.
- Do not reparent the VR rig to a root-level node unless the task explicitly requires a full architecture change.
- Keep quiz-flow scene wiring compatible with `QuestionManager` and `QuestionSceneRunner` expectations from `scenes/main.tscn`.

## Scenario Scene Requirements

- New question scenarios belong in `scenes/scenarios/`.
- Each scenario scene must provide a root-level `SpawnPoint` node for car placement.
- Scenario root script must extend `QuestionDriveScenario` for auto-drive support.
- For detailed creation workflow, patterns, and checklists, see `.github/instructions/scenario-setup.instructions.md`.
- If a scenario has no valid `SpawnPoint`, document the fallback behavior in the related script/resource change.

## Safe Editing Practices

- Prefer small, targeted scene edits over large structural rewrites.
- Keep node names stable when scripts/resources reference them by path.
- Preserve collision layers/masks unless the task explicitly changes interaction behavior.
- Avoid touching scenes under `addons/` unless intentionally patching third-party plugin code.

## XR and Interaction Conventions

- Keep OpenXR action bindings in `openxr_action_map.tres` (not the project input map).
- For in-car `Viewport2Din3D` UI scenes, keep compatibility with scripts that resolve gameplay nodes via `get_tree().current_scene`.

## Link, Don’t Duplicate

- Use `README.md` for Android/export/ADB workflows.
- Use `.github/copilot-instructions.md` for high-level architecture and pitfalls.- Use `.github/instructions/scenario-setup.instructions.md` for question scenario patterns and checklists.- Use `road_demos/README.md` for road-generator patterns and examples.
