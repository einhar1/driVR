---
description: "Use when creating question scenario scenes. Enforces QuestionDriveScenario inheritance, SpawnPoint requirements, and outcome logic patterns."
applyTo: "scenes/scenarios/**/*.tscn"
---

# Question Scenario Setup

For detailed step-by-step creation guide, see [`docs/question-scenario-setup.md`](../../docs/question-scenario-setup.md).

This file documents the essential **patterns and requirements** to follow when adding a new question scenario.

## Required Structure

### Scene Root

- Must be `Node3D`
- Must include a root-level `SpawnPoint` (Node3D or Marker3D) for car placement
- Script must extend `QuestionDriveScenario` (see below)

### Script Attachment

Every scenario root needs a GDScript that extends `QuestionDriveScenario`:

```gdscript
extends "res://scripts/scenarios/question_drive_scenario.gd"
class_name MyQuestionScenario

# Required for std questions:
func supports_default_drive_lane() -> bool:
	return true

func get_default_drive_lane() -> RoadLane:
	return _my_lane

func get_default_stop_target() -> Vector3:
	return _my_waypoint.global_position
```

## Question Type Patterns

### Standard Question (One Correct Answer)

**QuestionData fields:**

- `correct_index` – zero-based index into `options`
- `answer_outcomes` – **must be empty**

**Scenario script implements:**

- `supports_default_drive_lane() -> bool` – return `true`
- `get_default_drive_lane() -> RoadLane` – return valid lane or `null`
- `get_default_stop_target() -> Vector3` – return valid position

**Fallback:** If methods are missing or return `null`, quiz skips auto-drive and advances immediately.

### Outcome-Based Question (Multiple Routes)

**QuestionData fields:**

- `answer_outcomes` – array of outcome tags (e.g., `["left", "right", "straight"]`)
- Must have same length as `options`
- `correct_index` – **must be zero or unused** (all outcomes are treated as valid)

**Scenario script implements:**

- `supports_outcome_drive() -> bool` – return `true`
- `get_lane_for_outcome(p_outcome: String) -> RoadLane` – return lane for outcome tag
- `get_stop_target_for_outcome(p_outcome: String) -> Vector3` – return stop position for outcome tag

## node Hierarchy Checklist

- [ ] Root node is `Node3D`
- [ ] Script attached to root extends `QuestionDriveScenario`
- [ ] Root-level `SpawnPoint` exists (Node3D or Marker3D)
- [ ] Root-level `DriveWaypoint` exists (optional, used by `get_default_stop_target()`)
- [ ] Root-level `PanelSpawnPoint` exists (optional, custom quiz panel position)

## Core Implementation Checklist

### Standard Questions

- [ ] `supports_default_drive_lane()` returns `true`
- [ ] `get_default_drive_lane()` returns a valid `RoadLane` or `null`
- [ ] `get_default_stop_target()` returns a valid `Vector3` or `Vector3.INF`
- [ ] `QuestionData.correct_index` matches the intended correct option
- [ ] `QuestionData.answer_outcomes` is empty (`PackedStringArray()`)

### Outcome Questions

- [ ] `supports_outcome_drive()` returns `true`
- [ ] `get_lane_for_outcome()` returns valid `RoadLane` for each outcome tag
- [ ] `get_stop_target_for_outcome()` returns valid `Vector3` for each outcome tag
- [ ] `QuestionData.answer_outcomes` length equals `QuestionData.options` length
- [ ] Outcome strings match the tags used in the script

## Visbility and Physics

- Preserve collision layers/masks unless behavior change is intentional
- If player camera spawns inside the scenario, ensure no occluding geometry obstructs view
- Test with `player_in_car = true` (default) and `player_in_car = false` (if used)

## Testing

1. Create `resources/my_question.tres` (`QuestionData`)
2. Set `scene_path` to your scenario scene
3. Add to `resources/question_bank.tres`
4. In `scenes/main.tscn`, set `QuestionManager.debug_single_question = true` and index
5. Run and verify:
   - Car spawns at `SpawnPoint`
   - Quiz panel renders and accepts input
   - After answer, car drives (if configured) or advances

## Troubleshooting

| Issue                        | Check                                                                                           |
| ---------------------------- | ----------------------------------------------------------------------------------------------- |
| Car spawns in wrong location | `SpawnPoint` transform and rotation; `spawn_point_path` in QuestionData                         |
| No auto-drive after answer   | Missing `get_default_drive_lane()` / `get_default_stop_target()` or they return `null`          |
| Wrong answers accepted       | `answer_outcomes` is non-empty (indicates outcome-mode) — ensure `correct_index` is intentional |
| Quiz panel in wrong spot     | Add `PanelSpawnPoint` or set `panel_spawn_point_path` in QuestionData                           |
| Physics collision issues     | Verify physics layers/masks; check `player_in_car` setting in QuestionData                      |

## Links

- Detailed walkthrough: [`docs/question-scenario-setup.md`](../../docs/question-scenario-setup.md)
- Base class reference: `scripts/scenarios/question_drive_scenario.gd`
- Road lane patterns: `road_demos/README.md`
