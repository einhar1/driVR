# How to set up a new question scenario in driVR 2.0

This guide explains, step by step, how to add a brand-new quiz question with its own 3D scenario scene.

It is written for how this repository works **today**:

- `scenes/main.tscn` is the main gameplay scene
- `resources/question_bank.tres` stores the list of quiz questions
- `resources/question_data.gd` defines the fields each question uses
- `scripts/question_manager.gd` controls quiz state
- `scripts/question_scene_runner.gd` loads the scenario scene and moves the persistent car to the scenario spawn point
- `scripts/test_panel_controller.gd` shows the question UI and starts the car movement after the answer

If you follow the steps below, your new question should load correctly, place the car in the right spot, and advance through the quiz flow without drama.

---

## Quick mental model

When a question becomes active, the project does this:

1. `QuestionManager` picks the current `QuestionData`
2. `QuestionSceneRunner` loads that question's `scene_path`
3. The persistent car is moved to the scene's `SpawnPoint`
4. The in-car panel shows the `question` text and `options`
5. When the player answers:
   - if the question uses **normal quiz logic**, `correct_index` decides whether the answer is correct
   - if the question uses **outcome-based logic**, every answer is treated as valid and `answer_outcomes` decides what route the car should take
6. After a valid movement completes, the next question starts

So when you create a new question scenario, you are usually creating **three things**:

- a new scenario scene in `scenes/scenarios/`
- a new `QuestionData` resource in `resources/`
- a new entry in `resources/question_bank.tres`

---

## Choose which kind of scenario you are building

Before you create anything, decide which of these two patterns you want.

### Option A: standard question scenario

Use this when the question has one correct answer.

Examples:

- “What does this sign mean?”
- “Do you have right of way here?”
- “What color is a stop sign?”

How it works:

- `correct_index` is used
- `answer_outcomes` is left empty
- after a **correct** answer, the car will try to move using one of these:
  - a `get_default_stop_target()` method on the scenario root script
  - or a root-level node named `DriveWaypoint`
- optionally, the scenario script can also provide `get_default_drive_lane()` if you want lane-following instead of a simple waypoint drive

### Option B: outcome-based scenario

Use this when each answer corresponds to a different driving choice.

Example:

- “How do you want to drive?” → `left`, `right`, or `straight`

How it works:

- `answer_outcomes` must be filled in
- when `answer_outcomes` is non-empty, the code treats **every answer as valid**
- the scenario root script must provide:
  - `get_lane_for_outcome(p_outcome: String)`
  - `get_stop_target_for_outcome(p_outcome: String)`

If you skip these methods for an outcome-based question, the UI will accept the answer, but the car will have no valid route to follow. Sad car, sad day.

---

## Files involved in a new question scenario

In most cases, you will touch these files and folders:

- `scenes/scenarios/your_scenario.tscn` — the 3D scenario scene
- `scenes/scenarios/your_scenario.gd` — optional script for advanced movement logic
- `resources/your_question.tres` — the question resource
- `resources/question_bank.tres` — the master list of questions

Useful reference examples already in the repo:

- `scenes/scenarios/parkering.tscn` — simple scene with `SpawnPoint` and `DriveWaypoint`
- `scenes/scenarios/korsning.tscn` + `scenes/scenarios/korsning.gd` — standard question with custom lane/stop logic
- `scenes/scenarios/test_scenario3.tscn` + `scenes/scenarios/test_scenario3.gd` — outcome-based scene
- `resources/q1.tres`, `resources/q2.tres`, `resources/q3.tres`, `resources/korsning.tres` — example question resources

---

## Step 1: create the scenario scene

Create a new scene under:

- `scenes/scenarios/`

Recommended naming style:

- `yield_sign_scenario.tscn`
- `roundabout_question.tscn`
- `pedestrian_crossing_01.tscn`

### Root node requirements

The scenario scene should have a root node that inherits from `Node3D`.

That is required because `QuestionSceneRunner` instantiates the scene and expects it to be a `Node3D`.

If the root is not a `Node3D`, the scene will fail to load as a question scenario.

### Required node: `SpawnPoint`

Every scenario scene should include a **root-level** node named:

- `SpawnPoint`

Recommended type:

- `Node3D`
- `Marker3D` is also fine if you prefer a visible marker workflow, but the current code reads it as `Node3D`

What it does:

- this transform is used to place the persistent car when the scenario loads

Important details:

- the default `spawn_point_path` in `QuestionData` is `SpawnPoint`
- if your spawn node has that exact name and sits at the root of the scenario scene, you usually do **not** need to change `spawn_point_path`
- if you put the spawn node somewhere else, you must update `spawn_point_path` in the question resource

### What to place in the scene

Add the actual scenario content you need, for example:

- road layout
- signs
- props
- buildings
- NPC traffic
- environment meshes
- collision objects

If your scene uses roads and you expect lane-based driving, make sure road containers have:

- `generate_ai_lanes = true`

Without AI lanes, roads may look correct visually while the driving logic cannot find valid lanes.

---

## Step 2: position the spawn point correctly

Select the `SpawnPoint` node and place it where you want the player's car to appear.

### Good spawn placement rules

- place it on the road surface, not floating above or clipping below
- orient it so the car faces the intended starting direction
- leave enough space around the car to avoid collisions on load
- keep the spawn far enough from walls, props, and traffic cars

### How the transform is used

`QuestionSceneRunner` copies the `SpawnPoint` global transform onto the persistent car and then clears the car's linear and angular velocity.

That means:

- position matters
- rotation matters
- scale should normally remain `1,1,1`

If the car spawns sideways, backwards, or inside an object, the most likely culprit is simply the `SpawnPoint` transform.

---

## Step 3: decide how the car should move after the answer

This is the part people most often forget.

Loading the scenario is **not enough** by itself. If you want the quiz to flow naturally, the scene should also provide a destination for the car after the answer.

There are two supported ways to do this.

### Pattern 1: simple default movement with `DriveWaypoint`

For a normal question, the easiest option is to add a root-level marker named:

- `DriveWaypoint`

Recommended type:

- `Marker3D`

What it does:

- after a correct answer, `test_panel_controller.gd` looks for `DriveWaypoint`
- if found, the auto-driver uses that position as the stop target

This is the easiest setup and is usually enough for straightforward scenarios.

### Pattern 2: script-defined movement

If you need more control, attach a script to the **root node** of the scenario scene.

For a standard question, the scene may expose:

- `get_default_stop_target() -> Vector3`
- optionally `get_default_drive_lane() -> RoadLane`

For an outcome-based question, the scene must expose:

- `get_lane_for_outcome(p_outcome: String) -> RoadLane`
- `get_stop_target_for_outcome(p_outcome: String) -> Vector3`

This is the pattern used by:

- `scenes/scenarios/korsning.gd`
- `scenes/scenarios/test_scenario3.gd`

Use a root script when:

- you need different routes depending on the selected answer
- you want to use explicit road lanes
- you want to compute the stop target dynamically
- the lane you need does not already exist and must be created at runtime

---

## Step 4: create the `QuestionData` resource

Create a new resource in `resources/` using the custom type:

- `QuestionData`

Suggested file naming:

- `resources/q4.tres`
- `resources/yield_sign_question.tres`
- `resources/roundabout_entry.tres`

### Fields in `QuestionData`

The current resource has these important fields:

- `question: String`
- `options: PackedStringArray`
- `correct_index: int`
- `scene_path: String`
- `spawn_point_path: NodePath`
- `answer_outcomes: PackedStringArray`

### How to fill them in

#### `question`

Enter the text shown on the in-car panel.

Example:

- `Har du väjningsplikt här?`

#### `options`

Enter the answer button labels in order.

Examples:

- `Ja`, `Nej`
- `Vänster`, `Höger`, `Rakt`

The current UI supports up to **three** visible buttons.
Keep the option count to 1–3.

#### `correct_index`

Use this only for a normal question.

- `0` means the first option is correct
- `1` means the second option is correct
- `2` means the third option is correct

If you are making an outcome-based question, this value is effectively ignored because `answer_outcomes` makes every answer valid.

#### `scene_path`

Assign your new scenario scene here.

Example:

- `res://scenes/scenarios/yield_sign_scenario.tscn`

In saved `.tres` files, Godot may store this as a UID string instead of a literal `res://` path. That is normal.

#### `spawn_point_path`

If your scenario uses a root-level node named `SpawnPoint`, leave this as:

- `SpawnPoint`

Only change it if your spawn node lives somewhere else.

Examples:

- `SpawnPoint`
- `Markers/SpawnPoint`
- `RoadSetup/StartMarker`

#### `answer_outcomes`

Leave this empty for a standard question.

Fill it only for an outcome-based question.

Important rule:

- the number of `answer_outcomes` entries should match the number of `options`

Example:

- options: `Vänster`, `Höger`, `Rakt`
- answer_outcomes: `left`, `right`, `straight`

Those outcome strings must match what your scenario script expects.

---

## Step 5: add the new question to `question_bank.tres`

Open:

- `resources/question_bank.tres`

This resource contains the array of questions used by `QuestionManager` in `scenes/main.tscn`.

Add your new `QuestionData` resource to the `questions` array.

### Ordering matters

The order in `question_bank.tres` is the order used by the quiz.

So if you append your new question at the end, it becomes the last question in the cycle.

If you insert it in the middle, the quiz will reach it earlier.

---

## Step 6: save everything and verify scene references

Before testing, double-check these references.

### Checklist

- your scenario scene exists under `scenes/scenarios/`
- the root node is a `Node3D`
- the scene has a root-level `SpawnPoint`
- your `QuestionData.scene_path` points to the correct scene
- `spawn_point_path` matches the actual node path
- your new question is included in `resources/question_bank.tres`
- if using a normal question, `correct_index` is valid for the number of options
- if using an outcome-based question, `answer_outcomes.size()` matches `options.size()`
- if the car should move after the answer, the scene provides either:
  - `DriveWaypoint`, or
  - the expected script methods

---

## Step 7: test the question in isolation

The easiest way to test a new question without clicking through the full quiz is to use the debug fields on `QuestionManager` in `scenes/main.tscn`.

Open `scenes/main.tscn`, select `QuestionManager`, and use:

- `debug_run_single_question = true`
- `debug_question_index = <your question index>`

This makes the quiz repeatedly reload only that one question.

That is extremely useful when tuning:

- spawn placement
- button text
- answer logic
- lane routing
- waypoint placement
- traffic timing

When finished testing, turn `debug_run_single_question` back off.

---

## Step 8: run through the expected player flow

When you run `scenes/main.tscn`, verify the full flow:

1. the question appears on the panel
2. the scenario scene loads
3. the default environment is hidden while the scenario is active
4. the car appears at the correct `SpawnPoint`
5. the buttons show the right option texts
6. the answer behaves correctly:
   - wrong answer stays wrong for standard questions
   - correct answer starts movement for standard questions
   - any answer starts the matching route for outcome-based questions
7. after movement completes, the quiz advances to the next question

---

## Minimal setup recipes

## Recipe A: simplest possible standard question

Use this when you want the fastest working version.

### Recipe A scene setup

Create `scenes/scenarios/my_question_scene.tscn` with:

- a `Node3D` root
- `SpawnPoint` at the root
- `DriveWaypoint` at the root
- any meshes/colliders/signs you need

### Recipe A question resource

Create `resources/my_question.tres` with:

- `question` filled in
- `options` with 2 or 3 answers
- `correct_index` set correctly
- `scene_path` pointing to your scene
- `spawn_point_path = SpawnPoint`
- `answer_outcomes` empty

### Recipe A question bank entry

Add it to `resources/question_bank.tres`

This is the best starting point for most new questions.

---

## Recipe B: standard question with lane-aware movement

Use this when the car should follow a specific lane after a correct answer.

### Recipe B scene setup

Create the scene as above, but attach a root script that exposes:

- `get_default_stop_target()`
- optionally `get_default_drive_lane()`

### Recipe B question resource

Use a normal `correct_index` question.
Leave `answer_outcomes` empty.

### Recipe B reference files

- `scenes/scenarios/korsning.tscn`
- `scenes/scenarios/korsning.gd`

---

## Recipe C: outcome-based scenario

Use this when each answer maps to a different driving route.

### Recipe C scene setup

Create the scene and attach a root script that exposes:

- `get_lane_for_outcome(p_outcome: String)`
- `get_stop_target_for_outcome(p_outcome: String)`

### Recipe C question resource

Set:

- `options` to match the button texts
- `answer_outcomes` to match the script's expected outcome names

Example:

- options: `Vänster`, `Höger`, `Rakt`
- answer_outcomes: `left`, `right`, `straight`

### Recipe C reference files

- `scenes/scenarios/test_scenario3.tscn`
- `scenes/scenarios/test_scenario3.gd`
- `resources/q3.tres`

---

## Common mistakes and how to fix them

### The scenario scene does not load

Check:

- `scene_path` is assigned
- the scene file exists
- the scene root inherits `Node3D`

If the root is not `Node3D`, `QuestionSceneRunner` will reject it.

### The car does not move to the right place

Check:

- the scene has `SpawnPoint`
- `spawn_point_path` matches the actual node path
- the `SpawnPoint` rotation faces the correct direction

If the path is empty, the system falls back to `SpawnPoint`.
If no valid spawn point is found, the car position stays unchanged.

### The question loads, but the car does not drive after answering

For a standard question, check that the scene provides one of these:

- a root-level `DriveWaypoint`
- `get_default_stop_target()`

Optional but useful:

- `get_default_drive_lane()`

For an outcome-based question, check that the scene provides both:

- `get_lane_for_outcome(...)`
- `get_stop_target_for_outcome(...)`

### Roads are visible, but lane-based driving fails

Check each relevant `RoadContainer` node:

- `generate_ai_lanes = true`

This repository's road tooling depends on generated AI lanes for lane-following.

### The wrong answer is treated as correct

Check whether `answer_outcomes` is filled in.

If `answer_outcomes` is non-empty, the current logic treats **every answer as valid** and uses the outcome tags instead of `correct_index`.

So:

- standard question → leave `answer_outcomes` empty
- outcome-based question → fill `answer_outcomes` intentionally

### The buttons look wrong or do not match the intended answers

Check:

- `options` order
- `correct_index`
- `answer_outcomes` order

All three should line up by index.

---

## Recommended workflow for adding new scenarios

If you are adding several questions, this order tends to be the least painful:

1. create the scenario scene with just the environment and `SpawnPoint`
2. add `DriveWaypoint` or root script movement logic
3. create the `QuestionData` resource
4. add it to `question_bank.tres`
5. enable `debug_run_single_question`
6. test spawn position
7. test answer flow
8. tune movement and visuals
9. disable debug mode when done

This avoids trying to solve scene layout, data setup, and routing bugs all at once.

---

## Final pre-flight checklist

Before calling the scenario done, confirm all of this:

- [ ] Scene is in `scenes/scenarios/`
- [ ] Scene root is `Node3D`
- [ ] Root-level `SpawnPoint` exists
- [ ] `scene_path` in the question resource is correct
- [ ] `spawn_point_path` matches the scene
- [ ] Question was added to `resources/question_bank.tres`
- [ ] Option count is 1–3
- [ ] `correct_index` is valid for standard questions
- [ ] `answer_outcomes` is empty for standard questions
- [ ] `answer_outcomes` matches options for outcome-based questions
- [ ] Movement target exists (`DriveWaypoint` or script API)
- [ ] Lane-based scenes have `generate_ai_lanes = true` where needed
- [ ] The question works with `debug_run_single_question`

---

## Short example plan

If you wanted to add a new roundabout question, the practical sequence would be:

1. create `scenes/scenarios/roundabout_entry.tscn`
2. add a root `SpawnPoint`
3. add a root `DriveWaypoint`
4. build the road/sign environment
5. create `resources/roundabout_entry.tres` as a `QuestionData`
6. set the question text and options
7. set `correct_index`
8. assign `scene_path`
9. keep `spawn_point_path` as `SpawnPoint`
10. add the resource to `resources/question_bank.tres`
11. test it via `QuestionManager.debug_run_single_question`

That is the core workflow in one pass.

---

## Reference summary

### Required for every scenario scene

- location: `scenes/scenarios/`
- root node type: `Node3D`
- root-level spawn marker: `SpawnPoint`

### Required for every question resource

- entry in `resources/question_bank.tres`
- `question`
- `options`
- `scene_path`

### Required only for standard questions

- `correct_index`
- movement target after correct answer:
  - `DriveWaypoint`, or
  - `get_default_stop_target()`

### Required only for outcome-based questions

- `answer_outcomes`
- `get_lane_for_outcome(...)`
- `get_stop_target_for_outcome(...)`

---

If you want, the next useful follow-up would be to add a second document with a **copy-paste template** for:

- a minimal standard scenario scene/script
- a minimal outcome-based scenario scene/script
- a matching `QuestionData` example
