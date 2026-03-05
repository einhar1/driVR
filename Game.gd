extends Node3D


func _ready():
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 90
	else:
		printerr("OpenXR interface not found or failed to initialize.")
