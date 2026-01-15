# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

class_name CrabIdle
extends State

@onready var Crab : RigidBody3D = $"../.."
@onready var CrabScript : Node = $"../../Crab"
@onready var CrabMesh: Node3D = $"../../redcrab1"
var wander_location

@export var follow_speed: float = 4.0
@export var wander_speed: float = 3.0
var look_at_timer: float = 0.0

var check_to_attack_timer: float = 0.0
var check_dist_timer: float = 0.0
var water_settings_timer: float = 0.0

func Enter():
	$"../../redcrab1/AnimationPlayer".play("Walking")
	
	check_to_attack_timer = 0.5
	water_settings_timer = 0.0

func Exit():
	pass
	#if multiplayer.is_server():
		#transition_peers.rpc()

func Update(_delta):
	pass

func Physics_Update(delta):
	if CrabScript.look_at_player == null:
		wander_around(delta)
	else:
		follow()
		
		if check_to_attack_timer > 0: # every 0.2 check distance to go to attack
			check_to_attack_timer -= delta
		else:
			check_to_attack_timer = 0.2
			check_distance_to_player()
	
	
	if water_settings_timer > 0: # every 0.5 change water settings
		water_settings_timer -= delta
	else:
		water_settings_timer = 0.5
		crab_water_settings(CrabScript.look_at_player)

func follow():
	$"../../held_thrown".MAX_VELOCITY = follow_speed
	var direction = (CrabScript.look_at_player.global_position - Crab.global_transform.origin).normalized()
	
	if not Crab.submerged:
		direction.y = -0.25
	
	Crab.apply_central_force(direction * 10.0)
	
	if not %Footsteps.is_playing():
		%Footsteps.play()

func wander_around(delta):
	if wander_location == null:
		
		## Grabs first wander_loc
		wander_location = CrabScript.wander_locations.pop_front() 
		
	else:
		
		
		check_dist_timer -= delta
		if check_dist_timer < 0.0: #check distance every 0.25 seconds
			check_dist_timer = 0.25
			if wander_location.distance_to(Crab.global_transform.origin) < 10.0:
				## When crab reaches wander location, put wander_loc back in array
				CrabScript.wander_locations.push_back(wander_location)
				wander_location = null
				look_at_timer = 0.0
			
		else: 
			## Wander towards location
			var direction = (wander_location - Crab.global_transform.origin).normalized()
			
			if not Crab.submerged:
				direction.y = -0.25
			
			$"../../held_thrown".MAX_VELOCITY = wander_speed
			Crab.apply_central_force(direction * 20.0)
			
			if look_at_timer > 0.0:
				look_at_timer -= delta
			else:
				if Globals.look_at_pos(wander_location, CrabMesh, direction, true, 0.05):
					look_at_timer = 1.0
			
			if not %Footsteps.is_playing():
				%Footsteps.play()

@rpc("authority","call_remote","reliable")
func transition_peers():
	Transitioned.emit(self, "CrabAttack")

func check_distance_to_player():
	if Crab.global_position.distance_to(CrabScript.look_at_player.global_position) < 4: #4
		Transitioned.emit(self, "CrabAttack")


func crab_water_settings(plr):
	if plr == null:
		Crab.uses_water = true
		return
	
	if Globals.player_underwater_check(plr):#if underwater, change crab water settings
		Crab.uses_water = false
	else:
		Crab.uses_water = true

