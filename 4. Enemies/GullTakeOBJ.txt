# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

class_name GullTakeOBJ
extends State
 
@export var Gull : RigidBody3D
var unreachable_timer : float
var obj

var server_update = false

func Enter():
	obj = null
	obj = $"../GullIdle".OBJ_to_take
	
	if obj == null: #edge case
		Transitioned.emit(self,"GullIdle")
	
	$"../../held_thrown".MAX_VELOCITY = 6.0
	unreachable_timer = 10.0

func Exit():
	pass

func Update(delta):
	
	if obj == null:
		Transitioned.emit(self,"GullIdle")
	
	close_to_OBJ()
	
	if server_update:
		go_angry_if_held()
		countdown_unreachable_timer(delta)

func Physics_Update(_delta):
	fly()
	fly_to_OBJ()

#Check to see if the Gull is holding_obj to the object it is trying to get
func close_to_OBJ():
	if obj == null: return
	
	if Gull.global_position.distance_to(obj.global_position) < 1.0:
		
		#Update OBJ
		obj.get_child(0).held_by_seagull = true
		obj.freeze = true
		
		#In "IdleGull" script, used to transition Gull -> "AngryGull"
		$"../GullIdle".holding_obj = true
		
		Transitioned.emit(self,"GullIdle")

#Go towards OBJ
func fly_to_OBJ():
	if obj == null: return
	
	var target_position = obj.global_position
	var direction_to_target = (target_position - Gull.global_transform.origin).normalized()
	Gull.apply_central_force(direction_to_target * 20.0)

func fly():
	if Gull.global_position.y < 10.0:
		# See if Gull is close enough to holding_obj on the x and z axes to swoop down
		var obj_to_gull_z = abs(Gull.global_position.z - obj.global_position.z)
		var obj_to_gull_x = abs(Gull.global_position.x - obj.global_position.x)
		
		var distance_without_y = (obj_to_gull_z + obj_to_gull_x)
		
		if distance_without_y < 2.0:
			Gull.apply_central_force(Vector3.DOWN * 20.0)
		else:
			# Keep flying normally
			Gull.apply_central_force(Vector3.UP * 20.0)


@rpc("authority","call_local","reliable")
func transition_to_angry():
	Transitioned.emit(self, "GullAngry")

@rpc("authority","call_local","reliable")
func transition_to_idle():
	Transitioned.emit(self, "GullIdle")

func go_angry_if_held():
	if obj == null: return
	
	if obj.get_child(0).held:
		transition_to_angry.rpc()

func countdown_unreachable_timer(delta):
	if unreachable_timer > 0:
		unreachable_timer -= delta
	else:
		unreachable_timer = 10.0
		transition_to_idle_unreachable.rpc()

@rpc("authority","call_local","reliable")
func transition_to_idle_unreachable():
	$"../GullIdle".OBJ_to_take = null
	Transitioned.emit(self, "GullIdle")

