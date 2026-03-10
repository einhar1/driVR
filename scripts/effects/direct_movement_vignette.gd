@tool
extends XRToolsVignette

## Input action used by direct movement.
@export var direct_input_action: String = "primary"

## Inner vignette radius while direct movement is active.
@export_range(0.0, 1.0, 0.01) var inner_radius_when_moving: float = 0.35

## Time factor for fading back to full radius when not moving.
@export_range(0.1, 10.0, 0.1) var fade_out_speed: float = 1.5

## Deadzone threshold for movement input detection.
@export_range(0.0, 1.0, 0.01) var input_deadzone: float = 0.05

## Controller used to read direct movement input.
@onready var _left_controller: XRController3D = XRHelpers.get_left_controller(self)


func _ready() -> void:
	super()
	auto_adjust = false
	set_radius(1.0)
	set_process(true)


func _process(delta: float) -> void:
	if not _left_controller:
		_left_controller = XRHelpers.get_left_controller(self)
		
	if not _left_controller or not _left_controller.get_is_active():
		_fade_to_open(delta)
		return

	var input_vec: Vector2 = XRToolsUserSettings.get_adjusted_vector2(_left_controller, direct_input_action)
	var moving_direct: bool = input_vec.length() > input_deadzone

	if moving_direct:
		set_radius(inner_radius_when_moving)
	else:
		_fade_to_open(delta)


func _fade_to_open(p_delta: float) -> void:
	set_radius(min(1.0, radius + p_delta / fade_out_speed))
