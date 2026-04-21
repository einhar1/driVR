@tool
extends XRToolsStartXR

## XR startup wrapper that aligns the tracked HMD with the in-scene spawn anchor.
##
## OpenXR updates the camera pose from the headset at runtime, which can create an
## offset between authored spawn transforms and the user pose at startup.
## This script keeps your existing XRTools startup flow, then nudges the
## `XROrigin3D` so the headset lands at the intended seat position.

@export_group("Spawn Alignment")
@export var align_on_xr_started: bool = true
@export var align_once_per_run: bool = true
@export_range(1, 20, 1) var alignment_frames: int = 5
@export var align_vertical: bool = true
@export var min_offset_meters: float = 0.001
@export var xr_origin_path: NodePath = ^"car/DriversSeatAnchor/XROrigin3D"
@export var xr_camera_path: NodePath = ^"car/DriversSeatAnchor/XROrigin3D/XRCamera3D"

@export_group("Heading Alignment")
@export var align_heading_on_xr_started: bool = true
@export var seat_anchor_path: NodePath = ^"car/DriversSeatAnchor"
@export_range(-180.0, 180.0, 1.0) var heading_offset_degrees: float = 0.0

var _camera_baseline_local_position: Vector3 = Vector3.ZERO
var _origin_baseline_local_position: Vector3 = Vector3.ZERO
var _has_applied_spawn_alignment: bool = false
var _desktop_debug_added: bool = false


func _ready() -> void:
	_has_applied_spawn_alignment = false
	_cache_origin_baseline()
	_cache_camera_baseline()
	xr_started.connect(_on_xr_started)
	xr_failed_to_initialize.connect(_add_desktop_debug)
	super._ready()

	# Fallback: XR runtime found but no headset connected.
	if not Engine.is_editor_hint():
		_start_desktop_fallback()


func _start_desktop_fallback() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_xr_active() and not _desktop_debug_added:
		_add_desktop_debug()


## Spawns the desktop debug node for headset-free testing.
func _add_desktop_debug() -> void:
	if _desktop_debug_added:
		return
	_desktop_debug_added = true
	var debug_script: Script = load("res://scripts/desktop_debug.gd")
	if debug_script:
		var debug_node: Node = Node.new()
		debug_node.set_script(debug_script)
		debug_node.name = "DesktopDebug"
		add_child(debug_node)


func _on_xr_started() -> void:
	if not align_on_xr_started:
		return
	if align_once_per_run and _has_applied_spawn_alignment:
		return
	await _align_origin_for_spawn()
	_align_heading_for_spawn()
	await _align_origin_for_spawn()
	_has_applied_spawn_alignment = true


## Resets the player position and heading alignment. Can be called at any time.
func reset_player_position() -> void:
	await _align_origin_for_spawn()
	_align_heading_for_spawn()
	await _align_origin_for_spawn()


## Samples tracking over multiple frames and applies one averaged alignment.
func _align_origin_for_spawn() -> void:
	var xr_origin: XROrigin3D = get_node_or_null(xr_origin_path) as XROrigin3D
	var xr_camera: XRCamera3D = get_node_or_null(xr_camera_path) as XRCamera3D
	if xr_origin == null or xr_camera == null:
		return

	var accumulated_local_offset: Vector3 = Vector3.ZERO
	var sample_count: int = 0
	for _frame: int in range(alignment_frames):
		await get_tree().process_frame
		accumulated_local_offset += _get_camera_local_offset(xr_camera)
		sample_count += 1

	if sample_count <= 0:
		return

	var average_local_offset: Vector3 = accumulated_local_offset / float(sample_count)
	if average_local_offset.length() < min_offset_meters:
		return

	var offset_in_parent_space: Vector3 = xr_origin.transform.basis * average_local_offset
	xr_origin.position = _origin_baseline_local_position - offset_in_parent_space


## Caches authored origin local position used as the stable reset baseline.
func _cache_origin_baseline() -> void:
	var xr_origin: XROrigin3D = get_node_or_null(xr_origin_path) as XROrigin3D
	if xr_origin == null:
		return
	_origin_baseline_local_position = xr_origin.position


## Caches the authored camera local pose before tracking updates it.
func _cache_camera_baseline() -> void:
	var xr_camera: XRCamera3D = get_node_or_null(xr_camera_path) as XRCamera3D
	if xr_camera == null:
		return
	_camera_baseline_local_position = xr_camera.position


## Returns camera local tracking offset relative to the authored baseline.
func _get_camera_local_offset(p_xr_camera: XRCamera3D) -> Vector3:
	var local_offset: Vector3 = p_xr_camera.position - _camera_baseline_local_position
	if not align_vertical:
		local_offset.y = 0.0
	return local_offset


## Aligns headset yaw to the seat anchor forward vector.
func _align_heading_for_spawn() -> void:
	if not align_heading_on_xr_started:
		return

	var xr_origin: XROrigin3D = get_node_or_null(xr_origin_path) as XROrigin3D
	var xr_camera: XRCamera3D = get_node_or_null(xr_camera_path) as XRCamera3D
	var seat_anchor: Node3D = get_node_or_null(seat_anchor_path) as Node3D
	if xr_origin == null or xr_camera == null or seat_anchor == null:
		return

	var target_forward: Vector3 = - seat_anchor.global_transform.basis.z
	target_forward.y = 0.0
	if absf(heading_offset_degrees) > 0.001:
		target_forward = target_forward.rotated(Vector3.UP, deg_to_rad(heading_offset_degrees))
	if target_forward.length_squared() <= 0.000001:
		return
	target_forward = target_forward.normalized()

	var current_forward: Vector3 = - xr_camera.global_transform.basis.z
	current_forward.y = 0.0
	if current_forward.length_squared() <= 0.000001:
		return
	current_forward = current_forward.normalized()

	var signed_yaw: float = atan2(
		current_forward.cross(target_forward).y,
		current_forward.dot(target_forward)
	)
	if absf(signed_yaw) < 0.0001:
		return

	xr_origin.global_rotate(Vector3.UP, signed_yaw)
