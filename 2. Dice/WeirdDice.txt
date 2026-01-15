# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Script controls the dice the players throw to create OBJS, enemies, tornados, ect

## I won't lie, this script is pretty messy and only barely gets the job done.
## However it does some really cool things like the entire D20 and placing
## the correct things on each side of the dice dynmaically.

extends RigidBody3D

#region water
@export var float_force := 4.0
@export var water_drag := 0.05
@export var water_angular_drag := 0.05
@onready var water = get_tree().get_first_node_in_group("Water")
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var submerged := false
#endregion

@onready var objs = $Non_RayCasted/OBJS.get_children()
const MAX_VELOCITY = 10.0

var rolling = false
var rolling_toggle = true #check dice top every other phy frame
var held = false
var holder_id = -1
var last_holder_id = -1
var right_marker: Marker3D

var on_dice : Array
var off_dice : Array

var sides
var can_damage = false
var fuzz = false
var icecream = false
var max_held_timer:float = 0.0
var d_20_face_rotations = {
	# TOP
	15: Vector3(60, 90, 0),
	7:  Vector3(60, 162, 0),
	17: Vector3(60, 234, 0),
	10: Vector3(60, 306, 0),
	12: Vector3(60, 378, 0),
	
	# MID_TOP
	5: Vector3(20, 90, 0),
	1: Vector3(20, 162, 0),
	3: Vector3(20, 234, 0),
	8: Vector3(20, 306, 0),
	2: Vector3(20, 378, 0),
	
	# MID_BOT
	20: Vector3(0, -20, 0),
	18: Vector3(0, 52, 0),
	13: Vector3(0, 124, 0),
	19: Vector3(0, 196, 0),
	16: Vector3(0, 268, 0),
	
	# BOT
	14: Vector3(-50, -20, 0),
	4:  Vector3(-50, 52, 0),
	11: Vector3(-50, 124, 0),
	9:  Vector3(-50, 196, 0),
	6:  Vector3(-50, 268, 0),
}
var roll_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready(): 
	audio_setup()
	spawn_start()
	
	roll_rng.set_seed(Networking.lobby_seed)
	
	d_20_setup()

func _process(_delta):
	## keep dialog on top of dice at all times
	$DiceDia.global_position = self.global_position + Vector3(0,0.5,0)

func _physics_process(delta):
	if held and right_marker != null:
		hold_weird()
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
		
		if multiplayer.is_server(): show_new_item(side_value)
		else: send_server_top_side.rpc_id(1,side_value)


@rpc("any_peer","call_local","reliable")
func dice_thrown(id, knockback, six_also_thrown):
	if not held or holder_id != id:
		reset_dice()
		return
	
	held = false
	last_holder_id = holder_id #used in just rolled info, and top side
	
	set_collision_layer_value(3, true)
	
	var location = global_transform.origin - right_marker.get_child(0).global_transform.origin
	apply_central_impulse(location * knockback)
	
	if six_also_thrown and knockback > 2.5:
		both_thrown()
		DialogManager.good_throw()
	else:
		holder_id = 0
		DialogManager.bad_throw()

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
	
	holder_id = -1 #cant pickup till throw is done
	
	cheat_throw(x,z)
	
	DialogManager.dice_rolled += 1 ##Endgame Stats Dialog
	
	Globals.dice_rolled_ach()
	
	#so when others throw it doesnt send instantly
	await get_tree().create_timer(1.0).timeout
	rolling = true

func cheat_throw(x,z):
	$CheatThrowRayCast.rotation = Vector3(0,0,0)
	$CheatThrowRayCast.global_position = global_position
	
	await get_tree().create_timer(0.1).timeout
	
	var collider = $CheatThrowRayCast.get_collider()
	
	if collider != null:
		if str(collider.name) == "IslandStaticBody":
			apply_central_impulse(Vector3(x,2,z) * 3)
			apply_torque_impulse(Vector3(-x,2,-z) * 3)
			return

@rpc("any_peer","call_local","reliable")
func dice_held(id):
	if !held and holder_id == 0:
		held = true
		holder_id = id
		last_holder_id = -1
		
		$RunningParticles.emitting = false
		
		$HitParticles.emitting = false
		freeze = false ## Start
		
		set_collision_layer_value(3, false) #so it doesnt smack stuff
		
		var players = get_tree().get_nodes_in_group("Player")
		for player in players:
			if player.name == str(id):
				
				var cam = player.get_child(1)
				right_marker = cam.get_child(2) #current child node position for RIGHT


func held_countdown(delta):
	max_held_timer += delta
	if max_held_timer > 20:
		reset_dice()

func reset_dice():
	max_held_timer = 0.0
	rolling = false
	held = false
	holder_id = 0
	last_holder_id = 0
	can_damage = false
	right_marker = null
	
	set_collision_layer_value(3, true)
	
	for player in get_tree().get_nodes_in_group("Player"):
		player.weird_dice = false

#region Weird Dice stuff
## Weird Dice Funcs
func spawn_start():
	if Networking.dice_size == 6:
		var to_be_on_dice = objs.slice(0, 6) #first 6 items always
		place_objects_on_sides(to_be_on_dice)
		
		if not multiplayer.is_server(): return
		
		var remaining_objs = objs.slice(6, objs.size()) #get the remaining objs
		
		for obj in remaining_objs: #put the remaining objs in the off_dice
			off_dice.push_back(obj.get_name().to_int())
		
		off_dice.shuffle()

#used to place the items on the dice.
func place_objects_on_sides(first_six_objs):
	for i in 6:
		var obj = first_six_objs.pop_back()
		show_and_rotate_obj(obj, i)
		on_dice.push_back(obj.get_name().to_int()) #Add to Array

func show_new_item(side):
	#Server only Function
	if Networking.dice_size == 20: side -= 1
	
	var just_rolled_info_item_name = "Things"
	var just_rolled_info_player_name = "Someone"
	
	# Hides the obj
	for obj in objs:
		if obj.name == str(on_dice[side]):
			just_rolled_info_item_name = obj.get_child(0).name
			hide_obj(obj)
			break
	
	#Get item at corresponding side
	var side_item = on_dice[side]
	
	for player in get_tree().get_nodes_in_group("Player"):
		if str(player.name) == str(last_holder_id):
			just_rolled_info_player_name = player.get_node("%SteamName").text
			break
	
	Globals.set_weird(side_item, just_rolled_info_item_name, just_rolled_info_player_name)
	
	# choose new item
	var temp = on_dice[side]
	var new_item = choose_new_item()
	
	on_dice[side] = new_item
	off_dice.erase(new_item)  # Remove the chosen item from off_dice
	off_dice.append(temp)  # Add the old item to off_dice
	off_dice.shuffle()
	
	
	# shows the obj
	var index = on_dice.find( on_dice[side] ) # This is the Marker.name (0,1,2,3,4,5)
	
	
	for obj in objs:
		if obj.name == str(on_dice[side]):
			
			if Networking.dice_size == 6:
				show_and_rotate_obj(obj,index)
			elif Networking.dice_size == 20:
				d_20_show_and_rotate_obj(obj,index + 1)
			
			#send rpc to peers to swap the items
			show_new_item_peers.rpc(str(temp), str(on_dice[side]), index)
			break

@rpc("authority","call_remote","reliable")
func show_new_item_peers(old, new, index):
	for obj in objs:
		if obj.name == old:
			hide_obj(obj)
		if obj.name == new:
			
			if Networking.dice_size == 6:
				show_and_rotate_obj(obj,index)
			elif Networking.dice_size == 20:
				d_20_show_and_rotate_obj(obj,index + 1)

func show_and_rotate_obj(obj, num):
	obj.rotation = Vector3.ZERO
	match num:
		0:
			obj.rotate_x(deg_to_rad(180))
		1:
			obj.rotate_x(deg_to_rad(90))
		2:
			obj.rotate_y(deg_to_rad(90))
		3:
			obj.rotate_y(deg_to_rad(270))
		4:
			obj.rotate_x(deg_to_rad(270))
		5:
			pass #item is already in correct position
	
	## show sexy
	var obj_child = obj.get_child(0)  ## gets unique obj
	var old_pos = obj_child.position  ## gets old pos
	var old_scale = obj_child.scale   ## gets old scale
	obj_child.position = Vector3.ZERO ## Reset pos
	obj_child.scale = Vector3(0.01,0.01,0.01)    ## Reset scale
	obj.show()
	create_tween().tween_property(obj_child,"position",old_pos, 1.0).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(obj_child,"scale",old_scale, 1.0).set_ease(Tween.EASE_OUT)

func hide_obj(obj):
	var obj_child = obj.get_child(0)  ## gets unique obj
	var old_pos = obj_child.position  ## gets old pos
	var old_scale = obj_child.scale   ## gets old scale
	
	create_tween().tween_property(obj_child,"scale",Vector3.ZERO, 0.5).set_ease(Tween.EASE_OUT)
	var tween = create_tween()
	tween.tween_property(obj_child,"position",Vector3.ZERO, 0.75).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	obj.hide()
	obj_child.position = old_pos
	obj_child.scale = old_scale

func choose_new_item():
	if Networking.dice_size == 20: #need all the items i can get
		
		if off_dice[0] == 49: #ghost crab
			if !Globals.gems_defeated[7] or Networking.lobby_seed != 666: #after Spectral Fight
				return off_dice[1]
		
		return off_dice[0]
	
	for obj in off_dice:
		match obj:
			3: #palm trees
				if get_tree().get_nodes_in_group("Palm Tree").size() < 16: return obj
			
			35,36,37: #butterflys
				if get_tree().get_nodes_in_group("Butterfly").size() < 13: return obj
			
			38: #bushes
				if get_tree().get_nodes_in_group("Bush").size() < 9: return obj
			
			14: #bees
				if get_tree().get_nodes_in_group("Bush").size() > 1: return obj
			
			56: # snakes
				if get_tree().get_nodes_in_group("Bush").size() > 2: return obj
			
			52: #turtles
				if get_tree().get_nodes_in_group("Turtle").size() < 8: return obj
			
			7: #sharks
				if get_tree().get_nodes_in_group("Shark").size() < 10: return obj
			
			32: #eels
				if get_tree().get_nodes_in_group("Eel").size() < 9: return obj
			
			45: #pufferfish
				if get_tree().get_nodes_in_group("Pufferfish").size() < 9: return obj
			
			64: #jellyfish
				if get_tree().get_nodes_in_group("Pufferfish").size() < 10: return obj
			
			
			
			8, 9: # These items depend on red gem
				if Globals.gems_defeated[1] or Networking.lobby_seed == 666:
					return obj #king crab and rock knife
				
			51: # These items depend on green gem
				if Globals.gems_defeated[3] or Networking.lobby_seed == 666:
					return obj #coconut rain
			
			
			21:  # These items depend on blue gem 
				if Globals.gems_defeated[5] or Networking.lobby_seed == 666: 
					return obj #tornados
			
			49: #after Spectral Fight
				if Globals.gems_defeated[7] or Networking.lobby_seed == 666: 
					return obj #ghost crab
			
			11:  # Hammer
				var hams = get_tree().get_nodes_in_group("Hammer").size()
				var plrs = get_tree().get_nodes_in_group("Player").size()
				if hams < plrs:
					return obj
				
			_:  # Default case
				return obj
	
	printerr("WEIRD DICE RETURNED NOTHING")
	return null  # Fallback... will brick probs

#endregion

########################################################################### Good Funcs ###

## Hold
func hold_weird():
	var a = global_transform.origin
	var b = right_marker.global_transform.origin
	var c = a.distance_to(b)
	var calc = (a.direction_to(b)) * 10.0 * c
	set_linear_velocity(calc)
	set_angular_velocity(Vector3(-0.5, -0.5, -0.5))

## Send top side
@rpc("any_peer","call_remote","reliable")
func send_server_top_side(side_value):
	show_new_item(side_value)

## Audio
func audio_setup():
	$Audio/DiceRoll.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Audio/CommonBleeper.process_mode = Node.PROCESS_MODE_PAUSABLE

## Damage Hitbox
func _on_hitbox_body_entered(body):
	if can_damage and linear_velocity.length() > 2.0:
		
		if body.has_node("%HPBar"):
			var hp_node = body.get_node("%HPBar")
			hp_node.take_damage(1.0)

## Sides
func sides_setup(six_sides: bool = true):
	if six_sides:
		sides = get_tree().get_nodes_in_group("Weird_Dice_Side")
	else:
		sides = get_tree().get_nodes_in_group("20_Sided_Weird_Side")

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


#region Fuzzy and d20
func fuzzy():
	if fuzz: return
	
	fuzz = true #so only one instance of fuzz
	
	if Networking.dice_size == 6:
		var fuzz_scene = load("res://PairCross/Textures/Dice/FuzzyDice/fur_cube_weird.tscn")
		var fuzz_instance = fuzz_scene.instantiate()
		$Non_RayCasted/Cubes.add_child(fuzz_instance)
		$Non_RayCasted/OBJS.scale = Vector3(1.16, 1.16, 1.16)
	
	elif Networking.dice_size == 20:
		var fuzz_scene = load("res://PairCross/Textures/Dice/FuzzyDice/D20/d_20_fur_cube_weird.tscn")
		var fuzz_instance = fuzz_scene.instantiate()
		$D20/Mesh.add_child(fuzz_instance)
		
		$D20/Mesh/D20Mesh.hide()

func sundae():
	if icecream: return
	icecream = true
	
	var waffle_material = load("res://PairCross/Textures/Dice/D20/waffle_cone_texture.tres")
	$D20/Mesh/D20Mesh.set_surface_override_material(0,waffle_material)

func d_20_setup():
	if Networking.dice_size != 20: 
		sides_setup(true)
		return
	
	sides_setup(false)
	
	$D6.disabled = true
	$D20Large240.disabled = false
	
	$Non_RayCasted/Cubes.hide()
	$D20.show()
	
	for obj in $Non_RayCasted/OBJS.get_children():
		
		var mini_obj = obj.get_child(0)
		
		var obj_scale = mini_obj.scale
		var smaller_scale = obj_scale * 0.5
		
		mini_obj.scale = smaller_scale
		mini_obj.position.y -= 0.065
		mini_obj.position.z -= 0.065
		
		if mini_obj.name == "Coconut Rain": #coconut rain just had to be different ig
			mini_obj.position.y = -0.045
			mini_obj.position.z = -0.2
		
		if mini_obj.name == "Bushes": #coconut rain just had to be different ig
			mini_obj.position.y = -0.069
			mini_obj.position.z = -0.265
		
		if mini_obj.name == "Turtles": #coconut rain just had to be different ig
			mini_obj.position.y = -0.05
			mini_obj.position.z = -0.195
			
		if mini_obj.name == "Snakes": #coconut rain just had to be different ig
			mini_obj.position.y = -0.05
			mini_obj.position.z = -0.175
		
		if mini_obj.name == "Bees": #coconut rain just had to be different ig
			mini_obj.position.y = -0.05
			mini_obj.position.z = -0.321
	
	d_20_spawn_start()

func d_20_spawn_start():
	await get_tree().create_timer(5.0).timeout
	
	var to_be_on_dice = objs.slice(0, 20)
	d_20_place_objects_on_sides(to_be_on_dice)
	
	if not multiplayer.is_server(): return
	
	var remaining_objs = objs.slice(20, objs.size()) #get the remaining objs
	
	for obj in remaining_objs: #put the remaining objs in the off_dice
		off_dice.push_back(obj.get_name().to_int())
	
	off_dice.shuffle()

func d_20_show_and_rotate_obj(obj, num):
	obj.rotation = Vector3.ZERO
	
	var new_rotation = d_20_face_rotations[num]
	
	obj.rotate_x(deg_to_rad(new_rotation.x))
	obj.rotate_y(deg_to_rad(new_rotation.y))
	
	## show sexy
	var obj_child = obj.get_child(0)  ## gets unique obj
	var old_pos = obj_child.position  ## gets old pos
	var old_scale = obj_child.scale   ## gets old scale
	obj_child.position = Vector3.ZERO ## Reset pos
	obj_child.scale = Vector3.ZERO    ## Reset scale
	obj.show()
	create_tween().tween_property(obj_child,"position",old_pos, 1.0).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(obj_child,"scale",old_scale, 1.0).set_ease(Tween.EASE_OUT)

#used to place the items on the dice.
func d_20_place_objects_on_sides(first_twenty_objs):
	for i in 20:
		var obj = first_twenty_objs.pop_back()
		d_20_show_and_rotate_obj(obj, i + 1)
		on_dice.push_back(obj.get_name().to_int()) #Add to Array

#endregion

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
