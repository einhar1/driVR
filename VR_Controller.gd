extends XRController3D

@onready var hand_visual: Node3D = $HandVisual
@onready var grab_area: Area3D = $GrabArea

var held_object: RigidBody3D = null
var prior_parent: Node = null
var anim_player: AnimationPlayer = null

@export var grab_animation_name: String = ""
@export var release_animation_name: String = ""

var resolved_grab_anim: String = ""
var resolved_release_anim: String = ""


func _ready():
	anim_player = hand_visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_resolve_hand_animations()

	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)


func _on_button_pressed(action: String):
	if action == "grip_click":
		_play_grab_anim()
		if held_object == null:
			_grab()


func _on_button_released(action: String):
	if action == "grip_click":
		_play_release_anim()
		if held_object != null:
			_release()


func _play_hand_anim(anim_name: String):
	if anim_player and anim_name != "" and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)


func _play_grab_anim():
	_play_hand_anim(resolved_grab_anim)


func _play_release_anim():
	if anim_player == null:
		return

	if resolved_release_anim != "" and anim_player.has_animation(resolved_release_anim):
		if resolved_release_anim == resolved_grab_anim:
			# One combined animation (e.g. "Action"): play it backwards on release.
			anim_player.play_backwards(resolved_release_anim)
		else:
			anim_player.play(resolved_release_anim)


func _resolve_hand_animations():
	if anim_player == null:
		push_warning("%s: No AnimationPlayer found under HandVisual" % name)
		return

	var all_anims: PackedStringArray = anim_player.get_animation_list()
	print("%s hand animations: %s" % [name, ", ".join(all_anims)])

	resolved_grab_anim = _pick_animation_name(
		grab_animation_name,
		all_anims,
		["Grab", "grab", "Grip", "grip", "Close", "close", "Fist", "fist"]
	)
	resolved_release_anim = _pick_animation_name(
		release_animation_name,
		all_anims,
		["Release", "release", "Open", "open", "Idle", "idle", "Relax", "relax"]
	)

	if resolved_grab_anim == "" and all_anims.size() > 0:
		resolved_grab_anim = all_anims[0]
	if resolved_release_anim == "" and all_anims.size() > 0:
		resolved_release_anim = all_anims[0]

	if resolved_grab_anim != "" and resolved_grab_anim == resolved_release_anim:
		print("%s: Using single animation '%s' (forward on grab, backward on release)." % [name, resolved_grab_anim])


func _pick_animation_name(preferred: String, all_anims: PackedStringArray, fallbacks: Array[String]) -> String:
	if preferred != "" and all_anims.has(preferred):
		return preferred

	for anim_name in fallbacks:
		if all_anims.has(anim_name):
			return anim_name

	return ""


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
