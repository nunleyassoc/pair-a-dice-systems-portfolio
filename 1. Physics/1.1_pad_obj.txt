# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Script is used on every single Physics Object in the game
## This includes all the enemies like crabs and sharks to the rocks and baseball bat
## It includes general helper functions that 99% of OBJS use


class_name pad_obj
extends RigidBody3D

@export var damage : float = 1.0                       ## Damage the OBJ does
@export var uses_water : bool = true                   ## Toggle OBJ floating for underwater domes

@export var float_force := 5.0                         ## Amount of upward force used
@export var water_drag := 0.1                          ## Slows down OBJ velocity in water
@export var water_angular_drag := 0.1                  ## Slows down OBJ rotation in water

@onready var water = get_tree().get_first_node_in_group("Water")
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var submerged := false

@export var highlight_meshes: Array[MeshInstance3D]    ## Array of all the meshes to be Highlighted when the players mouse hovers over
@export var hl_amount: float = 1.05                    ## Amount of Highlighting

@export var edible: bool = false
@export var eat_hp: float = 0.25                       ## HP gained from eating something
@export var dizzy_chance: float = 1.0                  ## Chance that eating this OBJ will cause Dizzyness (balancing and world building)


## When a OBJ goes underwater, I apply a force upward to make it float
func _physics_process(_delta):
	submerged = false
	
	if uses_water:
		
		var depth = water.get_height(global_position) - global_position.y + 0.1
		if depth > 0:
			submerged = true
			apply_central_force(Vector3.UP * float_force * gravity * depth)


## Water Physics are done here to safely read and modify the simulation state for the object.
func _integrate_forces(state: PhysicsDirectBodyState3D):
	if submerged:
		state.linear_velocity *= 1 - water_drag
		state.angular_velocity *= 1 - water_angular_drag


## Every Phyics Object has a hitbox that detects if something should take damage
func _on_hitbox_body_entered(body):
	attack(body)


## Because everything is Physics based, everything can be used as a weapon as long as it's moving fast enough
func attack(enemy):
	if not enemy.has_node("%HPBar"): return
	
	var _vel = get_child(0).can_attack()
	
	if _vel == -1: return
	
	if linear_velocity.length() < _vel: return
	
	var hp_node = enemy.get_node("%HPBar")
	hp_node.take_damage(damage)


## When the player hovers over an object, I add a highlighted ring to show that the player can grab that object
func highlight(toggle_on:bool = true):
	if highlight_meshes == null: return
	
	if toggle_on:
		
		for mesh in highlight_meshes:
			mesh.material_overlay = Globals.highlight_material
			var tween = create_tween()
			tween.tween_property(mesh.material_overlay, "shader_parameter/size", hl_amount, 0.1).from(1.0)
	
	else:
		for mesh in highlight_meshes:
			mesh.material_overlay = null


## To regain Health, the player can eat anything. I shrink the scale of the object and remove collison before the server deletes it.
@rpc("any_peer","call_local","reliable")
func eat(pos):
	if not edible: return
	
	collision_layer = 0
	collision_mask = 0
	
	##EndGame Stats Dialog
	DialogManager.things_eaten += 1
	DialogManager.hp_healed += eat_hp
	
	if get_child(0).has_method("eat"):
		get_child(0).eat()
	
	#if has_node("%Dialog"):
		#%Dialog.understand_creature()
	
	for mesh in highlight_meshes:
		create_tween().tween_property(mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", pos, 0.25)
	await tween.finished
	
	hide()
	
	if multiplayer.is_server():
		await get_tree().create_timer(3.0).timeout
		queue_free()