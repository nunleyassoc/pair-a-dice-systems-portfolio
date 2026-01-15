# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

class_name EelIdle
extends State

@onready var Eel : RigidBody3D = $"../.."
@onready var EelScript = $"../../Eel"
@onready var EelMesh: Node3D = $"../../eel"

var wander_location
@onready var speed_value = $"../../held_thrown".MAX_VELOCITY
var speed_increment = 10.0
var look_at_timer: float = 0.0
var check_dist_timer: float = 0.0

func Enter():
	speed_value = 3.5
	$"../../held_thrown".MAX_VELOCITY = 3.5

func Exit():
	if multiplayer.is_server():
		transition_peers.rpc()

func Update(_delta):
	pass

func Physics_Update(delta):
	if EelScript.look_at_player != null:
		follow()
		inc_speed(delta)
	else:
		wander_around(delta)

func inc_speed(delta):
	if speed_value < 6.0:
		speed_value = min(speed_value + speed_increment * delta, 6.00)
		speed_value = clamp(speed_value,4,6)
		$"../../held_thrown".MAX_VELOCITY = speed_value
		
		var anim_speed = remap(speed_value, 3,6, 1,2)
		anim_speed = clamp(anim_speed, 1, 2)
		$"../../eel/AnimationPlayer".speed_scale = anim_speed

func follow():
	var direction = (EelScript.look_at_player.global_position - Eel.global_transform.origin).normalized()
	
	Eel.apply_central_force(direction * 20.0)
	
	if Eel.global_position.distance_to(EelScript.look_at_player.global_position) < 5:
		Transitioned.emit(self, "EelAttack")


func wander_around(delta):
	if not Eel.submerged and not Eel.get_child(0).in_tornado:
		var away_from_island = (Eel.global_position - Vector3.ZERO).normalized()
		away_from_island.y = -2.0
		Eel.apply_central_force(away_from_island * 10.0)
		wander_location = null
		look_at_pos(Eel.global_position + (away_from_island * 10.0))
	else:
		
		# Original wandering logic
		if wander_location == null: # Get new point
			
			wander_location = EelScript.get_random_wandering_point(Eel.global_position)
			
		else:
			
			check_dist_timer -= delta
			if check_dist_timer < 0.0: #check distance every 0.25 seconds
				check_dist_timer = 0.25
				if wander_location.distance_to(Eel.global_transform.origin) < 10.0:
					wander_location = null
					look_at_timer = 0.0
				
			else:
				# Wander towards location
				$"../../held_thrown".MAX_VELOCITY = 3.00
				speed_value = 3.0
				
				var direction = (wander_location - Eel.global_transform.origin).normalized()
				Eel.apply_central_force(direction * 20.0)
				
				if look_at_timer > 0.0:
					look_at_timer -= delta
				else:
					if Globals.look_at_pos(wander_location, EelMesh, direction, true, 0.05):
						look_at_timer = 1.0

func look_at_pos(target_position: Vector3):
	var t = EelMesh.global_transform.looking_at(target_position, Vector3.UP, true)
	
	EelMesh.global_transform.basis = EelMesh.global_transform.basis.slerp(t.basis, 0.05)
	EelMesh.rotation.x = 0.0
	EelMesh.rotation.z = 0.0


@rpc("authority","call_remote","reliable")
func transition_peers():
	Transitioned.emit(self, "EelAttack")
