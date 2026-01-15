# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Script controls the dice the players throw to create OBJS, enemies, tornados, ect


extends RigidBody3D

#region water vars
@export var float_force := 4.0
@export var water_drag := 0.05
@export var water_angular_drag := 0.05
@onready var water = get_tree().get_first_node_in_group("Water")
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var submerged := false
#endregion

const MAX_VELOCITY = 10.0

var rolling = false
var rolling_toggle = true #check dice top every other phy frame
var held = false
var holder_id = -1
var last_holder_id = -1
var left_marker: Marker3D

var max_held_timer: float = 0.0

var sides

var can_damage = false
var fuzz = false
var icecream = false
var roll_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var cheater_throws = 0

func _ready(): 
	audio_setup()
	roll_rng.set_seed(Networking.lobby_seed)
	d_20_setup()

func _process(_delta):
	## keep dialog on top of dice at all times
	$DiceDia.global_position = self.global_position + Vector3(0,0.5,0)

func _physics_process(delta):
	if held and left_marker != null:
		hold_six()
		held_countdown(delta)
	else:
		max_held_timer = 0.0
		clamp_velocity()
	
	if rolling:
		if rolling_toggle:
			find_top_side()
			rolling_toggle = false
		else: rolling_toggle = true
	
	submerged = false
	var depth = water.get_height(global_position) - global_position.y + 0.2
	if depth > 0:
		submerged = true
		apply_central_force(Vector3.UP * float_force * gravity * depth)



func find_top_side():
	var velocity = get_linear_velocity() ## Check if the dice has stopped moving
	if velocity.length() < 0.5:
		can_damage = false
		$RunningParticles.emitting = false
	
	if velocity.length() < 0.05 and angular_velocity.length() < 0.1: # Dice has stopped moving
		$HitParticles.emitting = false
		rolling = false
		
		if last_holder_id != multiplayer.get_unique_id(): return # whoever throws does the below
		
		if Globals.dice_boss_active: return
		
		var highest_side = 1
		var highest_y = -50
		
		for side in sides:
			if side.global_position.y > highest_y:
				highest_y = side.global_position.y
				highest_side = side
		
		var side_value = highest_side.get_name().to_int() #name -> int
		
		if multiplayer.is_server(): Globals.set_num_6(side_value)
		else: send_server_top_side.rpc_id(1,side_value)


@rpc("any_peer","call_local","reliable")
func dice_held(id):
	freeze = false
	$RunningParticles.emitting = false
	$HitParticles.emitting = false
	
	held = true
	holder_id = id
	last_holder_id = id
	
	set_collision_layer_value(3, false)
	
	for player in get_tree().get_nodes_in_group("Player"):
		if player.name == str(id):
			
			var cam = player.get_child(1)
			left_marker = cam.get_child(3) #current child node position for LEFT
			
			return


@rpc("any_peer","call_local","reliable")
func dice_thrown(id,knockback, weird_also_thrown):
	if not held or holder_id != id: 
		reset_dice()
		return
	
	set_collision_layer_value(3, true)
	
	held = false
	last_holder_id = holder_id #used in top side
	
	var location = global_transform.origin - left_marker.get_child(0).global_transform.origin
	apply_central_impulse(location * knockback)
	
	if weird_also_thrown and knockback > 2.5:
		both_thrown()
	else:
		holder_id = 0


func both_thrown():
	can_damage = true
	
	var x = roll_rng.randf_range(-1, 1)
	var y = roll_rng.randf_range(-1, 1)
	var z = roll_rng.randf_range(-1, 1)
	
	var rotation_force = Vector3(x, y, z) * 50.0
	apply_torque_impulse(rotation_force)
	
	$Audio/DiceRoll.play()
	$HitParticles.emitting = true
	$RunningParticles.emitting = true
	
	holder_id = -1 # cant pickup till throw is done
	
	cheat_throw(x,z)
	
	#so when others throw it doesnt send instantly
	await get_tree().create_timer(1.0).timeout
	rolling = true


func reset_dice():
	max_held_timer = 0.0
	rolling = false
	held = false
	holder_id = 0
	last_holder_id = 0
	can_damage = false
	left_marker = null
	
	set_collision_layer_value(3, true)
	
	for player in get_tree().get_nodes_in_group("Player"):
		player.six_sided_dice = false


func held_countdown(delta):
	max_held_timer += delta
	if max_held_timer > 20:
		reset_dice()
		#dice_thrown(holder_id,0,false)
		#Globals.my_player.six_sided_dice = false


########################################################################### Good Funcs ###

## Cheat
func cheat_throw(x,z):
	cheater_throws += 1
	
	$CheatThrowRayCast.rotation = Vector3(0,0,0)
	$CheatThrowRayCast.global_position = global_position
	
	await get_tree().create_timer(0.1).timeout
	
	var collider = $CheatThrowRayCast.get_collider()
	
	if collider != null:
		if str(collider.name) == "IslandStaticBody":
			apply_central_impulse(Vector3(x,2,z) * 3)
			apply_torque_impulse(Vector3(-x,2,-z) * 3)
			return

## Hold
func hold_six():
	var a = global_transform.origin
	var b = left_marker.global_transform.origin
	var c = a.distance_to(b)
	var calc = (a.direction_to(b)) * 10.0 * c
	set_linear_velocity(calc)
	set_angular_velocity(Vector3(0.5, 0.5, 0.5))

## Damage Hitbox
func _on_hitbox_body_entered(body):
	if can_damage and linear_velocity.length() > 2.0:
		
		if body.has_node("%HPBar"):
			var hp_node = body.get_node("%HPBar")
			hp_node.take_damage(1.0)

## Water Gravity
func _integrate_forces(state: PhysicsDirectBodyState3D):
	if submerged:
		state.linear_velocity *= 1 - water_drag
		state.angular_velocity *= 1 - water_angular_drag

## Clamp
func clamp_velocity():
	var velocity = linear_velocity
	if velocity.length() > MAX_VELOCITY:
		linear_velocity = velocity.normalized() * MAX_VELOCITY

## Sides
func sides_setup(six_sides: bool = true):
	if six_sides:
		sides = get_tree().get_nodes_in_group("6_Sided_Dice_Side")
	else:
		sides = get_tree().get_nodes_in_group("20_Sided_Dice_Side")

## Send top side
@rpc("any_peer","call_remote","reliable")
func send_server_top_side(side_value):
	Globals.set_num_6(side_value)

## Audio
func audio_setup():
	$Audio/CommonBleeper.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Audio/DiceRoll.process_mode = Node.PROCESS_MODE_PAUSABLE

## Fuzzy
func fuzzy():
	if fuzz: return
	
	fuzz = true #so only one instance of fuzz
	
	if Networking.dice_size == 6:
		var fuzz_scene = load("res://PairCross/Textures/Dice/FuzzyDice/fur_cube.tscn")
		var fuzz_instance = fuzz_scene.instantiate()
		$Non_RayCasted/Cubes.add_child(fuzz_instance)
	
	elif Networking.dice_size == 20:
		var fuzz_scene = load("res://PairCross/Textures/Dice/FuzzyDice/D20/d_20_fur_cube.tscn")
		var fuzz_instance = fuzz_scene.instantiate()
		$D20/Mesh.add_child(fuzz_instance)
		
		$D20/Mesh/D20Mesh.hide()

## Sundae
func sundae():
	if icecream: return
	icecream = true
	
	var waffle_material = load("res://PairCross/Textures/Dice/D20/ice_cream_texture.tres")
	$D20/Mesh/D20Mesh.set_surface_override_material(0,waffle_material)

func d_20_setup():
	if Networking.dice_size != 20: 
		sides_setup(true)
		return
	
	sides_setup(false)
	$D6.disabled = true
	$D20Large240.disabled = false
	
	$Non_RayCasted.hide()
	$D20.show()

## Dialog
func play_dialog(dia:String):
	%Dialog.display_text(dia)

func fade_dia():
	%Dialog.fade_text()

func _on_dialog_dialog_finished():
	pass # Replace with function body.

func _on_dialog_dialog_signal(value):
	if value == "interupt":
		DialogManager.can_interupt = true
