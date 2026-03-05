extends XRController3D

@onready var hand_mesh: MeshInstance3D = $HandMesh
@onready var grab_area: Area3D = $GrabArea

var held_object: RigidBody3D = null
var prior_parent: Node = null


func _ready():
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)


func _on_button_pressed(action: String):
	if action == "grip_click" and held_object == null:
		_grab()


func _on_button_released(action: String):
	if action == "grip_click" and held_object != null:
		_release()


func _grab():
	var closest: RigidBody3D = null
	var closest_dist := 9999.0

	for body in grab_area.get_overlapping_bodies():
		if body is RigidBody3D and body.is_in_group("pickable"):
			var dist = global_position.distance_to(body.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = body

	if closest == null:
		return

	held_object = closest
	prior_parent = held_object.get_parent()

	var obj_global_xform = held_object.global_transform
	prior_parent.remove_child(held_object)
	add_child(held_object)
	held_object.global_transform = obj_global_xform

	held_object.freeze = true


func _release():
	if held_object == null:
		return

	var obj_global_xform = held_object.global_transform
	remove_child(held_object)
	prior_parent.add_child(held_object)
	held_object.global_transform = obj_global_xform

	held_object.freeze = false

	# Apply controller velocity so the object can be thrown
	var xr_pose = get_pose()
	if xr_pose:
		held_object.linear_velocity = xr_pose.linear_velocity
		held_object.angular_velocity = xr_pose.angular_velocity

	held_object = null
	prior_parent = null
