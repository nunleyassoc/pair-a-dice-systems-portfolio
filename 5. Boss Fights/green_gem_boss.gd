extends Node3D

@onready var tree_rotate = $BossPalmTree/Rotate
@onready var boss_palm_tree = $BossPalmTree

@onready var take_damage_anim = $BossPalmTree/TakeDamageAnim

@onready var boss_tree_anim = $BossPalmTree/BossTreeAnim
@onready var tg_spawns = $TGSpawns

@onready var palm_tree_static_body = $BossPalmTree/Rotate/Scaler/Palm_Tree_C/PalmTreeStaticBody

@export var smack_loc: Vector3 = Vector3(15,15,15)

@onready var tree_sand = $TreeSand
@onready var sfx_marker = $BossPalmTree/Rotate/Scaler/Palm_Tree_C/SfxMarker


var server_player = false

var can_slap = false
var being_slapped = false

var mini_coco_tg = false

var bush_created = false
var bush_removed = false

var reverse_slam = false
var killed = false

var tween_time: float = 1.5
var atk_num = 0



#region bush
@onready var bush_mesh: MeshInstance3D = $BigBush/BushMesh

var bush
var flowers

@export var bush_shader: Shader
var leaves = preload("res://PairCross/Textures/Items/bush/Bush with Flowers_Leaves_NormalTree_C.png")
var mats = [
	preload("res://PairCross/Textures/Items/bush/Bush with Flowers_Flowers.png"),
	preload("res://PairCross/Textures/Items/bush/Bush with Flowers_Green.png"),
	preload("res://PairCross/Textures/Items/bush/Bush with Flowers_Blue.png"),
	preload("res://PairCross/Textures/Items/bush/Bush with Flowers_Orange.png")
]

func bush_spawn():
	var leaves_shader = ShaderMaterial.new()
	leaves_shader.shader = bush_shader  # Use the shared shader resource
	leaves_shader.set_shader_parameter("flower_texture", leaves)
	
	bush_mesh.set_surface_override_material(0, leaves_shader)
	bush = bush_mesh.get_surface_override_material(0)
	
	var flowers_shader = ShaderMaterial.new()
	flowers_shader.shader = bush_shader  # Use the shared shader resource
	flowers_shader.set_shader_parameter("flower_texture", mats[randi() % mats.size()])
	
	bush_mesh.set_surface_override_material(1, flowers_shader)
	flowers = bush_mesh.get_surface_override_material(1)
#endregion


func _ready():
	server_player = multiplayer.is_server()
	
	$Testing/TEMPIslandMesh.hide()
	
	%HPBar.armor = 0.9
	
	bush_spawn()
	
	boss_tree_anim.play("in")
	
	await get_tree().create_timer(10.5).timeout
	
	var players = get_tree().get_nodes_in_group("Player")
	var plr_amt = players.size() / 10.0
	plr_amt = clamp(plr_amt, 0.1, 0.4)
	
	%HPBar.armor = plr_amt
	
	tree_atk()

func tree_atk():
	if not server_player: return
	if killed: return
	
	atk_num += 1
	
	if atk_num > 2:
		atk_num = 0
	
	match atk_num:
		0:
			server_pick_player()
		1:
			tree_multiplayer.rpc(4)
		2:
			server_pick_player()


## ATTACKS ##

func tg_fight():
	#for i in 2:
	for coco in $TG.get_children():
		if killed: return
		coco.global_position = tg_spawns.get_child(randi() % 20).global_position #rand spawn
		coco.green_gem_fight(palm_tree_static_body)
		await get_tree().create_timer(0.1).timeout
	
	await get_tree().create_timer(0.25).timeout
	tree_atk()

func server_pick_player():
	var players = get_tree().get_nodes_in_group("Player")
	
	var random_player = players[randi() % players.size()]
	
	var plr_pos = random_player.global_position
	
	tree_multiplayer.rpc(3, plr_pos)

func tree_fall_towards_player(player_pos: Vector3):
	var tree_pos = tree_rotate.global_transform.origin
	var to_player = (player_pos - tree_pos).normalized()
	to_player.y = 0
	to_player = to_player.normalized()
	
	if to_player == Vector3.ZERO:
		printerr("TREE SLAM VEC 0 FAIL")
		tree_atk()
		return
	
	var axis = Vector3.UP.cross(to_player).normalized()
	var slam_angle_rad = deg_to_rad(90)
	var pre_angle_rad = deg_to_rad(-10)  # Small wind-up in opposite direction
	
	var pre_slam_basis = Basis(axis, pre_angle_rad)
	var slam_basis = Basis(axis, slam_angle_rad)
	
	var pre_rotation = pre_slam_basis.get_euler()
	var slam_rotation = slam_basis.get_euler()
	
	# Wind-up in opposite direction
	var tween_0 = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween_0.tween_property(tree_rotate, "rotation", pre_rotation, tween_time)
	
	await get_tree().create_timer(tween_time).timeout
	
	can_slap = true
	
	# Slam!
	var tween_1 = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween_1.tween_property(tree_rotate, "rotation", slam_rotation, tween_time)
	
	await get_tree().create_timer(tween_time - 0.25).timeout
	
	tree_sand.global_position = sfx_marker.global_position
	tree_sand.play()
	
	await get_tree().create_timer(0.25).timeout
	
	if reverse_slam:
		var triple_angle_rad = deg_to_rad(-85)
		var triple_slam_basis = Basis(axis, triple_angle_rad)
		var triple_slam_rotation = triple_slam_basis.get_euler()
		
		var trip_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		trip_tween.tween_property(tree_rotate, "rotation", triple_slam_rotation, tween_time)
		
		await get_tree().create_timer(tween_time - 0.25).timeout
		
		tree_sand.global_position = sfx_marker.global_position
		tree_sand.play()
		
		await get_tree().create_timer(0.25).timeout
	
	can_slap = false
	
	var tween_2 = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween_2.tween_property(tree_rotate, "rotation", Vector3.ZERO, tween_time)
	
	await get_tree().create_timer(tween_time).timeout
	
	tree_atk()


#region slap
func _on_slap_hitbox_body_entered(body):
	tree_slap(body)

func _on_baby_slap_hitbox_body_entered(body):
	tree_slap(body, false)

func tree_slap(player, deal_dmg: bool = true):
	if killed: return
	if not can_slap: return
	if being_slapped: return
	
	being_slapped = true
	
	if deal_dmg:
		if player.has_node("%HPBar"):
			var hp_node = player.get_node("%HPBar")
			hp_node.take_damage(1.5)
	
	var origin_pos = global_position
	var body_pos = player.global_transform.origin
	
	# Direction from tree to body (where the tree hit them)
	var flat_direction = (body_pos - origin_pos).normalized()
	flat_direction.y = 0  # Keep direction horizontal
	
	# Now create a point far away and high in that same direction
	var target_pos = body_pos + flat_direction * 50 + Vector3(0, 5, 0)
	
	var direction = (target_pos - player.global_transform.origin).normalized()
	
	player.set_motion_mode(1)
	await get_tree().process_frame #get player floating
	
	player.velocity = direction * 50.0
	await get_tree().create_timer(0.3).timeout
	player.set_motion_mode(0)
	
	being_slapped = false

#endregion


func _on_hp_bar_took_damage():
	take_damage_anim.play("take_damage")
	
	if not multiplayer.is_server(): return
	
	var tree_hp = %HPBar.real_value
	
	tween_time = remap(tree_hp, 0.0, 50.0, 0.7, 1.5)
	
	if tree_hp < 27 and not reverse_slam:
		reverse_slam = true
		tree_multiplayer.rpc(5)
	
	if tree_hp < 35 and not bush_created:
		tree_multiplayer.rpc(0)
	
	if tree_hp < 21 and not mini_coco_tg:
		mini_coco_tg = true
		
		var palm_tree_count = get_tree().get_nodes_in_group("Palm Tree")
		if palm_tree_count.size() < 15:
			Globals.num_6 = 6
			Globals.set_weird(3) ## Spawn Palm Trees
			## Palm Tree Spawn Animation is 1.5
			await get_tree().create_timer(1.50).timeout
		
		Globals.torch_god_fight.rpc(-1)
		tree_multiplayer.rpc(6)

func _on_bush_hitbox_body_entered(_body):
	if bush_removed: return
	
	bush_removed = true
	
	if not multiplayer.is_server(): return
	
	var pos = $BigBush/SpawnMarker.global_position
	
	#if Globals.gems_defeated[1]:
		#Globals.OBJ_Spawner.spawn([9,pos]) # King Crab node
	
	
	Globals.OBJ_Spawner.spawn([5,pos]) # crab node
	
	await get_tree().create_timer(0.1).timeout
	
	Globals.OBJ_Spawner.spawn([10,pos]) # gull node
	
	await get_tree().create_timer(0.1).timeout
	
	Globals.OBJ_Spawner.spawn([56,pos]) # snake node
	
	await get_tree().create_timer(0.1).timeout
	
	var rand_butterfly = randi_range(0,1)
	match rand_butterfly:
		0:
			Globals.OBJ_Spawner.spawn([35,pos]) # butterfly node
		1:
			Globals.OBJ_Spawner.spawn([36,pos]) # butterfly node
		2:
			Globals.OBJ_Spawner.spawn([37,pos]) # butterfly node
	
	await get_tree().create_timer(0.1).timeout
	
	Globals.OBJ_Spawner.spawn([14,pos]) # bee node
	
	await get_tree().create_timer(0.1).timeout
	
	Globals.OBJ_Spawner.spawn([5,pos])
	
	await get_tree().create_timer(0.1).timeout
	
	Globals.OBJ_Spawner.spawn([5,pos])
	
	await get_tree().create_timer(0.1).timeout
	
	if randi_range(0,1) == 0:
		Globals.OBJ_Spawner.spawn([5,pos]) # crab node
	
	tree_multiplayer.rpc(1)


func _on_hp_bar_zero_hp():
	if killed: return
	killed = true
	
	if not multiplayer.is_server(): return
	
	tree_multiplayer.rpc(2)
	
	if bush_created and not bush_removed:
		tree_multiplayer.rpc(1)
	
	await get_tree().create_timer(5.0).timeout
	var green_gem = get_tree().get_first_node_in_group("Green Fight Gem")
	green_gem.green_fight_end()
	await get_tree().create_timer(5.0).timeout
	
	queue_free()

@rpc("authority","call_local","reliable")
func tree_multiplayer(attack, plr_pos: Vector3 = Vector3(15,0,0) ):
	match attack:
		0:
			bush_created = true
			$BigBush/BushAnim.play("In")
		1:
			bush_removed = true
			$BigBush/BushAnim.play("Out")
			
			if Globals.my_player.global_position.distance_to(Vector3(0,5,0)) > 5:
				tree_slap(Globals.my_player, false)
		2:
			boss_tree_anim.play("out")
		3:
			tree_fall_towards_player(plr_pos)
		4:
			tg_fight()
		5:
			reverse_slam = true
		6:
			if Globals.my_player.global_position.distance_to(Vector3(0,5,0)) > 5:
				tree_slap(Globals.my_player, false)



