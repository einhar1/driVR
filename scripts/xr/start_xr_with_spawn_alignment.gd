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

var _camera_baseline_local_position: Vector3 = Vector3.ZERO
var _has_applied_spawn_alignment: bool = false


func _ready() -> void:
	_has_applied_spawn_alignment = false
	_cache_camera_baseline()
	xr_started.connect(_on_xr_started)
	super._ready()


func _on_xr_started() -> void:
	if not align_on_xr_started:
		return
	if align_once_per_run and _has_applied_spawn_alignment:
		return
	await _align_origin_for_spawn()
	_has_applied_spawn_alignment = true


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
	xr_origin.position -= offset_in_parent_space


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
