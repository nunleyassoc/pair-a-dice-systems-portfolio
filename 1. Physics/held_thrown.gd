# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Script is also used on every single Physics Object in the game
## Everything that can be held or thrown needs to be synced in multiplayer so players see the same things



class_name held_thrown
extends Node

@onready var OBJ : RigidBody3D = get_parent() ## Links to the pad_obj main OBJ script
var pickup: bool                              ## Pickups are treated differently, they have special functionalities

var MAX_VELOCITY = 20.0                       ## Max speed of an OBJ
var held = false                              ## Boolean deciding if the OBJ is held or not
var holder_id = 0                             ## The steam ID of the holder
var middle_marker : Marker3D                  ## The Marker3D node that the OBJ will be (The Players Hand)

var to_be_held_by_seagull = false             ## Decides if an OBJ is soon to be taken by a seagull
var held_by_seagull = false                   ## It is held by a seagull

var lerp_value = 0.1                          ## How fast to move a OBJ to the correct position
var lerp_increment = 5.0                      ## ^^

#region Tornado
var in_tornado: bool = false                  ## OBJS behave differntly in a tornado
var tornado_marker: Marker3D                  ## The Marker3D node the OBJ trys to go to (simulates tornado)
var time_passed: float = 0                    ## Tracks where the OBJ should be in orbit around the tornado
var orbit_distance: float = 15.0              ## Random Orbit Distance from the center of the tornado
var circle_period: float = 10.0               ## Random Time to complete a circle of the tornado
var height_offset: float = 0.0                ## Random Height offset from center of tornado
#endregion


## Decides how a held / thrown Item should act
func _physics_process(delta):
	if held and not OBJ.is_freeze_enabled():
		hold_middle()
	else:
		clamp_velocity()
		
		if in_tornado:
			time_passed += delta
			tornado(time_passed)


## Pickup OBJ's have special functionality like Baseball bats, Bows, Magic Wands, ect
func _process(delta):
	if held and OBJ.is_freeze_enabled():
		hold_pickup(delta)


## Important Multiplayer call to hold an OBJ
@rpc("any_peer","call_local","reliable")
func middle_held(id):
	if !held and holder_id == 0:
		held = true
		holder_id = id
		OBJ.freeze = false #unfreezes the object (coconut, held_by_gull)
		
		OBJ.set_collision_layer_value(5, false)
		OBJ.set_collision_mask_value(5, false)
		OBJ.set_collision_layer_value(6, true)
		
		held_by_seagull = false
		to_be_held_by_seagull = false
		
		var players = get_tree().get_nodes_in_group("Player")
		for player in players:
			if player.name == str(id):
				
				player.picked_middle = OBJ
				
				var cam = player.get_child(1)
				middle_marker = cam.get_child(1)
				
				if pickup:
					get_child(0).pickup(player)
				
				break


## Important Multiplayer call to throw an OBJ
@rpc("any_peer","call_local","reliable")
func middle_thrown(id,knockback):
	if held and holder_id == id:
		held = false
		holder_id = 0
		lerp_value = 0.0
		
		OBJ.set_collision_layer_value(5, true)
		OBJ.set_collision_mask_value(5, true)
		OBJ.set_collision_layer_value(6, false)
		
		if pickup:
			get_child(0).item_thrown()
			if get_child(0).item and knockback < 1.0:
				knockback = 1.0
		
		var location = OBJ.global_transform.origin - middle_marker.get_child(0).global_transform.origin
		OBJ.apply_central_impulse(location * knockback)


## How RigidBody3D OBJ's are held
func hold_middle():
	var a = OBJ.global_position
	var b = middle_marker.global_position
	var c = a.distance_to(b)
	var calc = (a.direction_to(b)) * 10.0 * c
	OBJ.set_linear_velocity(calc)
	OBJ.set_angular_velocity(Vector3(-0.5, -0.5, -0.5))


## For RigidBody3D OBJ's that need to be held still
## This occurs in the Process func so it doesn't look jittery
## First the OBJ gradually goes to the correct position until it's stays on the markers position perfectly
func hold_pickup(delta):
	lerp_value = min(lerp_value + lerp_increment * delta, 1.0)
	OBJ.global_transform = OBJ.global_transform.interpolate_with(middle_marker.global_transform, lerp_value)


## Makes sure OBJ's don't go flying away too quickly
func clamp_velocity():
	var velocity = OBJ.linear_velocity
	if velocity.length_squared() > MAX_VELOCITY * MAX_VELOCITY:
		OBJ.linear_velocity = velocity.normalized() * MAX_VELOCITY


## Called on the Object the Seagull is trying to take 
## So that the var: "idle.OBJ_to_take" can be set for all players (all players see the same thing this way)
@rpc("authority","call_local","reliable")
func seagull_held(id):
	if held_by_seagull: return
	if to_be_held_by_seagull: return #Makes sure no other Seagulls are trying to get this OBJ
	if held: return #Makes sure player isn't holding item
	if holder_id != 0: return
	
	var gulls = get_tree().get_nodes_in_group("Gull")
	for gull in gulls:
		if gull.name == str(id):
			
			to_be_held_by_seagull = true
			
			#Relay that this OBJ is being taken and Transition Gull to "GullTakeOBJ"
			if gull.has_node("State Machine/GullIdle"):
				var idle = gull.get_node("State Machine/GullIdle")
				idle.OBJ_to_take = OBJ
				idle.transition()
			
			return


## Tornado!!!
func tornado(time):
	# Calculate position on the circular path
	var t = (fposmod(time, circle_period) / circle_period) * 2 * PI
	var x = cos(t) * orbit_distance
	var y = tornado_marker.global_position.y + height_offset
	var z = sin(t) * orbit_distance
	var target_position = tornado_marker.global_position + Vector3(x, y, z)
	
	var a = OBJ.global_position
	var c = a.distance_to(target_position)
	var calc = (a.direction_to(target_position)) * c * 0.75
	
	OBJ.set_linear_velocity(calc)
	OBJ.set_angular_velocity(Vector3(-0.5, -0.5, -0.5))


## Reset vars when something is eaten
func eat():
	held = false
	middle_marker = null
	holder_id = -1
	to_be_held_by_seagull = true


## stops seagull and peers items from accidentally killing ex: bees
func can_attack(): 
	if held_by_seagull: return -1
	
	if held:
		if str(Globals.my_player.name) != str(holder_id):
			#print("this is not my item")
			return -1
		else:
			#this is my item
			return 5.5
	
	#item is thrown, increase velocity needed
	return 7.5

func reset_held_thrown():
	if holder_id > 0:
		held = true
		middle_thrown(holder_id,5)
