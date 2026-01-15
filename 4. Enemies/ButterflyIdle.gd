# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

class_name ButterflyIdle
extends State

@onready var Butterfly : RigidBody3D = $"../.."
@onready var butterfly_mesh = $"../../butterfly"

enum ButterflyType {ELECTRIC, FIRE, HP}
@export var Type: ButterflyType = ButterflyType.ELECTRIC

var wander_location
var ai_rng = RandomNumberGenerator.new()
var look_at_timer: float = 0.0
var check_dist_timer: float = 0.0

func Enter():
	ai_rng.set_seed(Globals.ai_seed)
	Globals.ai_seed += 1
	$"../../held_thrown".MAX_VELOCITY = 4.00

func Exit():
	pass

func Update(_delta):
	pass

func Physics_Update(delta):
	wander_around(delta)
	butterfly_mesh.global_position = Butterfly.global_position

func wander_around(delta):
	if wander_location == null:
		# Get new point
		wander_location = get_random_wandering_point(Butterfly.global_position)
		look_at_timer = 0.0
	else:
		
		check_dist_timer -= delta
		if check_dist_timer < 0.0: #check distance every 0.25 seconds
			check_dist_timer = 0.25
			if wander_location.distance_to(Butterfly.global_transform.origin) < 5.0:
				wander_location = null
				look_at_timer = 0.0
			
		else:
			# Wander towards location
			
			var direction = (wander_location - Butterfly.global_transform.origin).normalized()
			Butterfly.apply_central_force(direction * 20.0)
			
			if look_at_timer > 0.0:
				look_at_timer -= delta
			else:
				
				if Globals.look_at_pos(wander_location, butterfly_mesh, direction):
					look_at_timer = 1.0


func get_random_wandering_point(butterfly_pos: Vector3, min_dis: float = 5, max_dis: float = 50.0) -> Vector3:
	var directions = [
		Vector3(1, 0, 0),  # Right
		Vector3(-1, 0, 0), # Left
		Vector3(0, 0, 1),  # Forward
		Vector3(0, 0, -1), # Backward
		Vector3(1, 0, 1).normalized(),  # Forward-Right
		Vector3(-1, 0, 1).normalized(), # Forward-Left
		Vector3(1, 0, -1).normalized(), # Backward-Right
		Vector3(-1, 0, -1).normalized() # Backward-Left
	]
	
	var vertical_movement = ai_rng.randf_range(5, 27)
	
	for i in range(directions.size()):
		var random_direction = directions[ai_rng.randi() % directions.size()]
		var random_distance = ai_rng.randf_range(min_dis, max_dis)
		var new_position = butterfly_pos + random_direction * random_distance
		
		# Adjust the vertical position to be within the 5-25 range
		new_position.y = vertical_movement
		
		# Use the boundary check to ensure the new position is valid
		if is_within_bounds(new_position, max_dis):
			return new_position
	
	# Fallback points if no valid random wandering point is found
	var fallback_positions = [
		Vector3(10, 10, 10),
		Vector3(10, 10, -10),
		Vector3(-10, 10, 10),
		Vector3(-10, 10, -10)
	]
	
	# Choose a random fallback point
	return fallback_positions[ai_rng.randi() % fallback_positions.size()]

func is_within_bounds(pos: Vector3, max_dis: float = 50.0) -> bool:
	var distance_to_origin = Vector3(pos.x, 0, pos.z).distance_to(Vector3.ZERO)
	return distance_to_origin <= max_dis

func _on_hp_bar_zero_hp():
	DialogManager.enemys_killed += 1
	Transitioned.emit(self, "ButterflyDead")
