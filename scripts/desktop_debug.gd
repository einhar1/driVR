extends Node

## Desktop debug fallback for testing without a VR headset.
##
## Automatically activates when XR is unavailable. Spawns a [Camera3D] at the
## driver-seat position with mouse-look and crosshair-click interaction for
## the in-world quiz panel ([code]Viewport2Din3D[/code]).
##
## [b]Controls:[/b][br]
## - Mouse motion → look around[br]
## - Left click → interact with quiz panel (when crosshair is on it)[br]
## - Click the window → capture cursor[br]
## - [code]Escape[/code] → release cursor

@export var mouse_sensitivity: float = 0.002
## Maximum raycast distance for panel interaction.
@export var interact_distance: float = 5.0

var _camera: Camera3D
var _active: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _current_target: Node3D
var _last_hit_pos: Vector3


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# If XR is already confirmed inactive (spawned by xr_failed_to_initialize),
	# activate immediately. Otherwise wait for the fallback timer in the parent.
	if not XRToolsStartXR.is_xr_active():
		call_deferred("_enable_desktop_mode")


func _enable_desktop_mode() -> void:
	if _active:
		return
	_active = true

	var seat: Node3D = get_tree().current_scene.get_node_or_null("car/DriversSeatAnchor")
	if not seat:
		push_error("DesktopDebug: DriversSeatAnchor not found")
		return

	# Create a standard Camera3D at the driver's eye position.
	# XROrigin3D is at Y -1.1 from seat, XRCamera3D at Y 1.7 from origin → net Y 0.6.
	_camera = Camera3D.new()
	_camera.name = "DesktopDebugCamera"
	seat.add_child(_camera)
	_camera.position = Vector3(0.0, 0.6, 0.0)
	_camera.current = true

	# Ensure the viewport is not in XR mode so the desktop camera renders.
	get_viewport().use_xr = false

	_add_crosshair()

	print("Desktop debug mode — click window to capture mouse, ESC to release, look at panel + click to answer")


func _unhandled_input(p_event: InputEvent) -> void:
	if not _active or not is_instance_valid(_camera):
		return

	if p_event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= p_event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - p_event.relative.y * mouse_sensitivity, -1.4, 1.4)
		_camera.rotation = Vector3(_pitch, _yaw, 0.0)

	if p_event is InputEventMouseButton and p_event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if p_event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_handle_pointer_click(p_event.pressed)

	if p_event is InputEventKey and p_event.pressed and p_event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(_delta: float) -> void:
	if not _active or not is_instance_valid(_camera):
		return
	_update_pointer_hover()


## Updates hover state by raycasting from the screen centre each physics tick.
func _update_pointer_hover() -> void:
	var hit: Dictionary = _raycast_center()
	if hit.is_empty():
		if is_instance_valid(_current_target):
			XRToolsPointerEvent.exited(_camera, _current_target, _last_hit_pos)
			_current_target = null
		return

	var body: Node3D = hit["collider"]
	var pos: Vector3 = hit["position"]

	if body != _current_target:
		if is_instance_valid(_current_target):
			XRToolsPointerEvent.exited(_camera, _current_target, _last_hit_pos)
		_current_target = body
		XRToolsPointerEvent.entered(_camera, _current_target, pos)
	else:
		XRToolsPointerEvent.moved(_camera, _current_target, pos, _last_hit_pos)

	_last_hit_pos = pos


## Sends press/release pointer events to whatever the crosshair is aimed at.
func _handle_pointer_click(p_pressed: bool) -> void:
	var hit: Dictionary = _raycast_center()
	if hit.is_empty():
		return

	var body: Node3D = hit["collider"]
	var pos: Vector3 = hit["position"]

	if p_pressed:
		XRToolsPointerEvent.pressed(_camera, body, pos)
	else:
		XRToolsPointerEvent.released(_camera, body, pos)


## Casts a ray from the camera through the exact centre of the viewport.
func _raycast_center() -> Dictionary:
	if not _camera.is_inside_tree():
		return {}

	var world_3d: World3D = _camera.get_world_3d()
	if world_3d == null:
		return {}

	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space_state == null:
		return {}

	var vp_size: Vector2 = _camera.get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return {}

	var center: Vector2 = vp_size / 2.0
	var from: Vector3 = _camera.project_ray_origin(center)
	var to: Vector3 = from + _camera.project_ray_normal(center) * interact_distance

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	# Layers 21 (Pointable Objects) + 23 (UI Objects).
	query.collision_mask = 0b0000_0000_0101_0000_0000_0000_0000_0000
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)


## Adds a small "+" crosshair overlay at the screen centre.
func _add_crosshair() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center_container)

	var crosshair: Label = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 32)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_container.add_child(crosshair)
