# Add a new question scenario (quick guide)

This is the **short, beginner-friendly** way to add a new quiz question with its own 3D scenario in driVR 2.0.

---

## What gets added

For one new question, you usually add:

1. A scenario scene in `scenes/scenarios/`
2. A `QuestionData` resource in `resources/`
3. That resource to `resources/question_bank.tres`

---

## How quiz flow works (today)

When a question becomes active:

1. `QuestionManager` selects a `QuestionData`
2. `QuestionSceneRunner` loads `scene_path`
3. Persistent car is moved to `spawn_point_path` (default `SpawnPoint`)
4. Quiz panel shows `question` + `options`
5. Player answers
6. Based on setup, the app either:
   - starts auto-drive, or
   - advances to next question immediately

---

## Step 1: create the scenario scene

Create a scene in `scenes/scenarios/`, for example:

- `scenes/scenarios/roundabout_entry.tscn`

### Required

- Root node must be `Node3D`
- Add a root-level `SpawnPoint` (`Node3D` or `Marker3D`)

If `SpawnPoint` is missing (and no custom spawn path is valid), the car keeps its old position.

### Optional but useful

- Root-level `DriveWaypoint` (simple post-answer target)
- Root-level `PanelSpawnPoint` (custom panel placement)

> `PanelSpawnPoint` is new in the flow: if present (or configured via `panel_spawn_point_path`), the in-world panel is placed there. Otherwise it uses the default offset from the car.

---

## Step 2: choose question type

### A) Standard question (one correct answer)

Use:

- `correct_index`
- empty `answer_outcomes`

For movement after correct answer, provide one of:

- `DriveWaypoint`, or
- scene root method `get_default_stop_target()`

Optional lane-based method:

- `get_default_drive_lane()`

### B) Outcome-based question (each option is a route)

Use:

- filled `answer_outcomes`
- (here every selected option is treated as valid)

Scene root script must provide:

- `get_lane_for_outcome(p_outcome: String)`
- `get_stop_target_for_outcome(p_outcome: String)`

---

## Step 3: create `QuestionData` resource

Create a new `QuestionData` in `resources/`, for example `resources/q4.tres`.

Fill these fields:

- `question`: text on panel
- `options`: 1-3 options (UI currently shows max 3)
- `scene_path`: your scenario scene
- `spawn_point_path`: usually `SpawnPoint`

Then choose behavior fields:

- `correct_index`: for standard questions
- `answer_outcomes`: for outcome-based questions (same length/order as `options`)

### New fields to know

- `panel_spawn_point_path` (default `PanelSpawnPoint`)
  - Lets you place the quiz panel at a scenario anchor
- `post_answer_action`
  - `Auto Drive`: wait for drive completion before next question
  - `Advance Immediately`: skip driving and advance after short delay
- `player_in_car`
  - `true`: car stays visible/active
  - `false`: persistent car is hidden and frozen during the question

---

## Step 4: add to question bank

Open `resources/question_bank.tres` and add your new `QuestionData` to `questions`.

Order in this array is quiz order.

---

## Step 5: test only this question

In `scenes/main.tscn`, select `QuestionManager` and set:

- `debug_run_single_question = true`
- `debug_question_index = <index of your new entry>`

Now you can iterate quickly on one scenario.

When done, set `debug_run_single_question` back to `false`.

---

## Mini checklists

### Standard question checklist

- [ ] Scene root is `Node3D`
- [ ] Root `SpawnPoint` exists
- [ ] `scene_path` is correct
- [ ] `correct_index` matches `options`
- [ ] `answer_outcomes` is empty
- [ ] Post-answer target exists (`DriveWaypoint` or `get_default_stop_target()`)

### Outcome-based checklist

- [ ] Scene root is `Node3D`
- [ ] Root `SpawnPoint` exists
- [ ] `answer_outcomes.size() == options.size()`
- [ ] Outcome strings match scene script logic
- [ ] Scene has both outcome methods

### Optional new-feature checklist

- [ ] If custom panel placement is needed: `PanelSpawnPoint` exists or `panel_spawn_point_path` is set
- [ ] `post_answer_action` is intentionally chosen
- [ ] `player_in_car` is intentionally chosen

---

## Common gotchas

- **Scene loads but car spawns wrong**  
  Check `spawn_point_path`, `SpawnPoint` transform, and rotation.

- **Answer accepted but no driving**  
  Missing `DriveWaypoint`/default methods (standard) or missing outcome methods (outcome-based).

- **Wrong answers are accepted**  
  `answer_outcomes` is non-empty, so all options are treated as valid by design.

- **Panel appears in wrong place**  
  Add/fix `PanelSpawnPoint` or `panel_spawn_point_path`.

---

## Fast recipe (copy workflow)

1. Create `scenes/scenarios/my_scene.tscn` (root `Node3D`)
2. Add root `SpawnPoint`
3. Add root `DriveWaypoint` (or script methods)
4. Create `resources/my_question.tres` (`QuestionData`)
5. Set `question`, `options`, `correct_index` (or `answer_outcomes`)
6. Set `scene_path`
7. Add to `resources/question_bank.tres`
8. Test with single-question debug mode

Done. No drama, only driving theory.
