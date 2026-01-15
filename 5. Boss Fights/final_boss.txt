# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Script Controls the Final Boss Fight's attacks

extends Node3D

@onready var dice = $Dice
@onready var weird_dice = $WeirdDice

@onready var dice_anim: AnimationPlayer = $Dice/DiceAnim
@onready var weird_dice_anim: AnimationPlayer = $WeirdDice/WeirdDiceAnim
@onready var both_dice_anim: AnimationPlayer = $BothDiceAnim

@onready var smash_shell_1 = $Extras/SmashShell1
@onready var smash_shell_2 = $Extras/SmashShell2

@onready var lava_height_anim = $Lava/LavaHeightAnim

@onready var dice_dead_particles = $Dice/DiceDead
@onready var weird_dice_dead_particles = $WeirdDice/WeirdDiceDead

@onready var volcanos = $Extras/Volcanos

var killed = false

var can_attack = false # toggles the process func

var time_before_anim: float = 2.5 # speed of tweens

var dice_attack_timer: float  = 2.00 ############################### BETTER WAYS TO DO THIS
var weird_attack_timer: float  = 3.00 ############################## BETTER WAYS TO DO THIS
var dice_attacking = false ######################################### BETTER WAYS TO DO THIS
var weird_dice_attacking = false ################################### BETTER WAYS TO DO THIS

var waiting_for_dual_attack = false # makes both dice start do dual attacks
var waiting_for_dice_roll = false # start dice roll
var waiting_for_crush = false

var cup_speed: float = 170.0
var dice_collide_damage = false # deal damage on collison toggle
var weird_collide_damage = false
var crushing = false # crush kill toggle
var crush_toggle = false # 2 different crush anims
var roll_pull = 0 # dir sent flying from white dice roll

var lava_level = 0 # lava rising toggle

func _ready():
	$Lava.show()
	$TEMPIslandMesh.hide() #hide island mesh
	
	Globals.dice_boss_active = true
	
	var water = get_tree().get_first_node_in_group("Water")
	water.global_position.y = -7
	
	directly_spawned_check()
	
	var players = get_tree().get_nodes_in_group("Player")
	var plr_amt = (players.size() / 100.0) * 3
	plr_amt = clamp(plr_amt, 0.01, 0.25)
	
	%HPBar.armor = plr_amt

func start_boss_fight():
	volcanos.erupting = true
	
	await get_tree().create_timer(3.0).timeout
	
	boom_box_crab()
	
	await get_tree().create_timer(7.4).timeout
	
	if multiplayer.is_server():
		dice_lava.rpc()
	
	Globals.gems_defeated[10] = true
	delete_prison()

@rpc("authority","call_local","reliable")
func dice_lava():
	both_dice_anim.play("out_lava")


func _process(delta):
	if not can_attack or killed: return
	
	if dice_attack_timer > 0:
		dice_attack_timer -= delta
	else:
		dice_attack_timer = time_before_anim
		
		if not dice_attacking: 
			dice_attacks()
	
	if weird_attack_timer > 0:
		weird_attack_timer -= delta
	
	else:
		weird_attack_timer = time_before_anim
		
		if not weird_dice_attacking: 
			weird_dice_attacks()


func _physics_process(_delta):
	if crushing:
		smash_shell_1.global_position = dice.global_position
		smash_shell_2.global_position = weird_dice.global_position

func dice_attacks():
	if waiting_for_dual_attack:
		dual_attacks(true) #sends true = dice
		waiting_for_dual_attack = false
		return
	
	var attack = Globals.boss_dice_rng.randi_range(0,5)
	
	match attack:
		0:start_roll_over_island(true)
		1:start_roll_over_island(false)
		2:start_shooting_dots()
		3:start_shooting_dots()
		4:cup_start(true)
		5:crush_start(true)

func weird_dice_attacks():
	if waiting_for_dual_attack:
		dual_attacks(false) #sends false = weird dice
		waiting_for_dual_attack = false
		return
	
	var attack = Globals.boss_dice_rng.randi_range(0,5)
	
	match attack:
		0:king_crab_spawn()
		1:king_crab_spawn()
		2:if !%FireNado.can_spin: fire_nado()
		3:if !%FireNado.can_spin: fire_nado()
		4:cup_start(false)
		5:crush_start(false)

func dual_attacks(type: bool = true):
	if waiting_for_dice_roll:
		cup_start(type)
	if waiting_for_crush:
		crush_start(type)

################################# NORMAL DICE ONLY ################################

#region DOTS

## Fire Dots - 2.5 sec before 6.1 sec anim = 8.6 total
func start_shooting_dots():
	dice_attacking = true
	
	var num = Globals.boss_dice_rng.randi_range(1,5)
	var rand_marker = get_node("DiceBossMarkers/SkyMarkers/SkyMarker" + str(num))
	var pos = rand_marker.global_position
	
	create_tween().tween_property(dice,"global_position",pos, time_before_anim)
	create_tween().tween_property(dice,"rotation",Vector3.ZERO, time_before_anim)
	
	await get_tree().create_timer(time_before_anim + 0.5).timeout
	
	if kild(): return
	
	dice_anim.play("ShootDots")

func fire_dots(side_num: int = 0):
	var side: Node3D
	
	match side_num:
		1: side = $Dice/Mesh/Side1
		2: side = $Dice/Mesh/Side2
		3: side = $Dice/Mesh/Side3
		4: side = $Dice/Mesh/Side4
		5: side = $Dice/Mesh/Side5
		6: side = $Dice/Mesh/Side6
	
	var markers = side.get_children()
	
	for marker in markers:
		marker.get_child(0).fire(marker)
		await get_tree().create_timer(0.1).timeout

func end_shooting_dots():
	dice_attacking = false

#endregion

#region WHITE DICE ROLL

## Roll On Island - 2 sec before 7.4 sec anim = 9.4 total
func start_roll_over_island(atk_style_1:bool = true):
	dice_attacking = true
	
	if atk_style_1:
		roll_pull = 1
		
		var pos = Vector3(41, 24.797, 0)
		var rot = Vector3(0, 0, deg_to_rad(-200))
		
		create_tween().tween_property(dice,"global_position",pos, time_before_anim)
		create_tween().tween_property(dice,"rotation", rot , time_before_anim)
		
		await get_tree().create_timer(time_before_anim).timeout
		
		if kild(): return
		
		dice_anim.play("roll_over_island")
	
	else:
		roll_pull = 2
		
		var pos = Vector3(0, 24.797, 41.295)
		var rot = Vector3(0, deg_to_rad(90), deg_to_rad(600))
		
		create_tween().tween_property(dice,"global_position",pos, time_before_anim)
		create_tween().tween_property(dice,"rotation", rot, time_before_anim)
		
		await get_tree().create_timer(time_before_anim).timeout
		
		if kild(): return
		
		dice_anim.play("roll_over_island_2")


func change_roll_pull(new_pull: int = 2):
	roll_pull = new_pull

func _on_dice_roll_hitbox_body_entered(body):
	if kild(): return
	
	var pull_marker
	match roll_pull:
		0: return
		1: pull_marker = $"DiceBossMarkers/RollPullMarkers/1"
		2: pull_marker = $"DiceBossMarkers/RollPullMarkers/2"
	
	var direction = (pull_marker.global_transform.origin - body.global_transform.origin).normalized()
	
	body.set_motion_mode(1)
	await get_tree().process_frame #get player floating
	
	body.velocity = direction * 100.0
	await get_tree().create_timer(0.3).timeout
	body.set_motion_mode(0)

func end_roll_over_island():
	dice_attacking = false
	roll_pull = 0

#endregion

################################# WEIRD DICE ONLY #################################

#region SPAWN KING CRAB

## King Crab Spawn - 2 sec before, 7 sec waiting, 2.5 going back up to sky = 11.5
func king_crab_spawn():
	weird_dice_attacking = true
	
	var num = Globals.boss_dice_rng.randi_range(1,4)
	var rand_sky_marker = get_node("DiceBossMarkers/KingCrabMarkers/KingCrabSkyMarker" + str(num))
	var sky_pos = rand_sky_marker.global_position
	
	create_tween().tween_property(weird_dice,"global_position",sky_pos, time_before_anim / 2)
	create_tween().tween_property(weird_dice,"rotation",Vector3(0,deg_to_rad(45),0), time_before_anim)
	
	await get_tree().create_timer(time_before_anim / 2).timeout
	
	if kild(): return
	
	var pos = rand_sky_marker.get_child(0).global_position
	create_tween().tween_property(weird_dice,"global_position",pos, time_before_anim / 2)
	
	if multiplayer.is_server(): spawn_king_c()
	
	await get_tree().create_timer(7.0).timeout
	
	if kild(): return
	
	var tween = create_tween()
	tween.tween_property(weird_dice,"global_position",sky_pos, time_before_anim + 0.5)
	await tween.finished
	
	weird_dice_attacking = false

func spawn_king_c():
	await get_tree().create_timer(time_before_anim / 2).timeout
	
	if kild(): return
	
	var king_crab_pos = %KingCrabSpawnMarker.global_position
	Globals.OBJ_Spawner.spawn([9,king_crab_pos])

#endregion

#region FIRENADO

## FireNado - 2 sec before, 1 wait, 1 going up = 5
func fire_nado():
	weird_dice_attacking = true
	
	Globals.check_achievement(23) # Firenado Ach
	
	var sky_pos = Vector3(-41.0, 25.0, -41.0)
	var dice_lava_pos = Vector3(-41.0, 0.0, -41.0)
	var dice_rotation = Vector3(deg_to_rad(45),deg_to_rad(45),0)
	
	var tornado_pos = Vector3(-30.0, 0.0, -30.0)
	
	## Get to POS IN SKY
	create_tween().tween_property(weird_dice,"global_position", sky_pos, time_before_anim / 2)
	create_tween().tween_property(weird_dice,"rotation", Vector3.ZERO, time_before_anim / 2)
	await get_tree().create_timer(time_before_anim / 2).timeout
	
	if kild(): return
	
	## Get to POS IN LAVA
	create_tween().tween_property(weird_dice,"global_position",dice_lava_pos, time_before_anim / 2)
	await get_tree().create_timer(time_before_anim / 2).timeout
	
	if kild(): return
	
	## Spawn Tornado
	%FireNado.global_position = %KingCrabSpawnMarker.global_position
	%FireNado.on_off()
	
	await get_tree().create_timer(0.5).timeout
	
	if kild(): return
	
	##Rotate Dice and Move Tornado
	create_tween().tween_property(weird_dice,"rotation", dice_rotation, 0.5)
	create_tween().tween_property(%FireNado,"global_position", tornado_pos, 0.5)
	await get_tree().create_timer(0.5).timeout
	
	if kild(): return
	
	%FireNado.start_spin()
	
	## Get to POS IN SKY
	await get_tree().create_timer(time_before_anim / 2).timeout
	
	if kild(): return
	
	create_tween().tween_property(weird_dice,"global_position", sky_pos, time_before_anim / 2)
	create_tween().tween_property(weird_dice,"rotation", Vector3.ZERO, time_before_anim / 2)
	await get_tree().create_timer(time_before_anim / 2).timeout
	
	weird_dice_attacking = false

#endregion

###################################### BOTH #######################################

#region CUP DICEROLL

## Cup DiceRoll
func cup_start(type: bool = true):
	var idler # idle one dice before dice roll so sync
	var lava_loc = Vector3(40,20,50) #pos it sinks into lava at
	
	if type:
		idler = dice
		dice_attacking = true
		lava_loc = Vector3(50,20,40)
	else:
		idler = weird_dice
		weird_dice_attacking = true
	
	waiting_for_dual_attack = true
	
	var play_anim = true
	if not waiting_for_dice_roll:
		waiting_for_dice_roll = true
		play_anim = false
	
	var rand_rot = idler.rotation + Vector3(1,1,1) * 1.25
	create_tween().tween_property(idler, "rotation", rand_rot, time_before_anim * 2.0).as_relative()
	
	create_tween().tween_property(idler, "global_position", lava_loc, time_before_anim)
	await get_tree().create_timer(time_before_anim).timeout
	
	if kild(): return
	
	var lava_loc_lower = lava_loc + Vector3(0, -40, 0)
	
	create_tween().tween_property(idler, "global_position", lava_loc_lower , time_before_anim)
	await get_tree().create_timer(time_before_anim).timeout
	
	if kild(): return
	
	dice_collide_damage = true
	weird_collide_damage = true
	
	if play_anim:
		both_dice_anim.play("cup_start")

func cup_exit():
	if kild(): return
	
	both_dice_anim.play("cup_exit")
	
	dice.freeze = false
	weird_dice.freeze = false
	
	dice.set_collision_layer_value(1, true)
	weird_dice.set_collision_layer_value(1, true)
	
	var dice_pos = Globals.my_player.global_position
	var dice_dir = (dice_pos - dice.global_position).normalized()
	dice.apply_central_impulse(dice_dir * 170)
	
	var weird_pos = Globals.my_player.global_position
	var weird_dir = (weird_pos - weird_dice.global_position).normalized()
	weird_dice.apply_central_impulse(weird_dir * 170)
	
	await get_tree().create_timer(time_before_anim + 1.0).timeout
	
	dice.freeze = true
	weird_dice.freeze = true
	
	dice.set_collision_layer_value(1, false)
	weird_dice.set_collision_layer_value(1, false)
	
	waiting_for_dice_roll = false
	
	dice_attacking = false
	weird_dice_attacking = false
	
	dice_collide_damage = false
	weird_collide_damage = false
	
	dice_attack_timer = 0.1
	weird_attack_timer = 0.25

func _on_dice_hurtbox_body_entered(body):
	if dice_collide_damage and not killed:
		if body.has_node("%HPBar"):
			var hp_node = body.get_node("%HPBar")
			
			hp_node.take_damage(4.5, false)

func _on_weird_dice_hurtbox_body_entered(body):
	if weird_collide_damage and not killed:
		if body.has_node("%HPBar"):
			var hp_node = body.get_node("%HPBar")
			
			hp_node.take_damage(4.5, false)

#endregion

#region CRUSH

## Crush
func crush_start(type: bool = true):
	var idler # idle one dice before dice roll so sync
	var lava_loc = Vector3(-7,20,-30) #pos it sinks into lava at
	
	if type:
		idler = dice
		dice_attacking = true
		lava_loc = Vector3(7,20,-30)
	else:
		idler = weird_dice
		weird_dice_attacking = true
	
	waiting_for_dual_attack = true
	
	var play_anim = true
	if not waiting_for_crush:
		waiting_for_crush = true
		play_anim = false
	
	var rand_rot = idler.rotation + Vector3(1,1,1) * 1.25
	create_tween().tween_property(idler, "rotation", rand_rot, time_before_anim * 2.0).as_relative()
	
	create_tween().tween_property(idler, "global_position", lava_loc, time_before_anim)
	await get_tree().create_timer(time_before_anim).timeout
	
	if kild(): return
	
	var lava_loc_lower = lava_loc + Vector3(0, -40, 0)
	create_tween().tween_property(idler, "global_position", lava_loc_lower , time_before_anim)
	
	await get_tree().create_timer(time_before_anim).timeout
	
	if kild(): return
	
	if play_anim:
		
		if crush_toggle:
			both_dice_anim.play("crush_start")
		else:
			both_dice_anim.play("crush_start_2")
		
		crush_toggle = !crush_toggle
		
		crushing = true
		dice_collide_damage = false
		weird_collide_damage = false
		smash_shell_1.get_child(0).set_collision_layer(1)
		smash_shell_2.get_child(0).set_collision_layer(1)

func crush_end():
	if kild(): return
	
	waiting_for_crush = false
	
	dice_attacking = false
	weird_dice_attacking = false
	
	crushing = false
	
	dice_attack_timer = 0.1
	weird_attack_timer = 0.25
	
	smash_shell_1.global_position = Vector3(0, -100, 0)
	smash_shell_2.global_position = Vector3(0, -100, 10)
	
	smash_shell_1.get_child(0).set_collision_layer(0)
	smash_shell_2.get_child(0).set_collision_layer(0)

func _on_crush_hitbox_body_entered(body):
	if not crushing: return
	if killed: return
	
	if body.has_node("%HPBar"):
		var hp_node = body.get_node("%HPBar")
		
		hp_node.take_damage(30, false)

#endregion




## ANIM END ##

func _on_both_dice_anim_animation_finished(anim_name):
	if anim_name == "out_lava":
		can_attack = true
		await get_tree().create_timer(1.0).timeout
		start_roll_over_island(false)
		if !%FireNado.can_spin: fire_nado()
	
	if anim_name == "cup_start":
		cup_exit()
	
	if anim_name == "crush_start":
		crush_end()
	if anim_name == "crush_start_2":
		crush_end()



func _on_hp_bar_took_damage():
	var dice_hp = %HPBar.real_value
	
	time_before_anim = remap(dice_hp, 0.0, 100.0, 1.0, 2.5)
	var anim_speed_scale = remap(dice_hp, 0.0, 100.0, 1.25, 1.0)
	var cup_speed_up = remap(dice_hp, 0.0, 100.0, 200, 170)
	
	dice_anim.speed_scale = anim_speed_scale
	weird_dice_anim.speed_scale = anim_speed_scale
	both_dice_anim.speed_scale = anim_speed_scale
	
	cup_speed = cup_speed_up
	
	#print("Tween Time: ", time_before_anim)
	#print("Animm Time: ", anim_speed_scale)
	
	lava_rising(dice_hp)


func _on_hp_bar_zero_hp():
	if killed: return
	
	killed = true
	
	lava_sinking()
	
	Globals.check_achievement(22)
	
	Globals.boom_box_boss_fight = -1
	Globals.fade_player_bg()
	
	dice_dead_particles.emitting = true
	weird_dice_dead_particles.emitting = true
	
	dice_anim.speed_scale = 1.0
	weird_dice_anim.speed_scale = 1.0
	both_dice_anim.speed_scale = 1.0
	
	Globals.gems_defeated[11] = true
	
	Globals.my_player.get_node("%BossHp").toggle_boss_hp_bar(false)
	Globals.my_player.get_node("%HPBar").invincible = true
	
	if not Globals.my_player.alive:
		Globals.my_player.get_node("%DownedBar").revive_request(-99)
	
	if both_dice_anim.is_playing():
		both_dice_anim.pause()
	if dice_anim.is_playing():
		dice_anim.pause()
	if weird_dice_anim.is_playing():
		weird_dice_anim.pause()
	
	create_tween().tween_property(dice, "global_position", Vector3(30,20,7), 3)
	create_tween().tween_property(weird_dice, "global_position", Vector3(30,20,-7), 3)
	
	await get_tree().create_timer(3.0).timeout
	
	create_tween().tween_property(dice, "global_position", Vector3(30,-20,7), 5)
	create_tween().tween_property(weird_dice, "global_position", Vector3(30,-20,-7), 5)
	
	await get_tree().create_timer(3.0).timeout
	
	var s_m = Globals.my_player.get_node("Movement State Machine")
	s_m.on_child_transition(s_m.current_state, "EndGame")
	
	if multiplayer.is_server() and not Globals.end_game_spawned:
		Globals.end_game_spawned = true
		var pos = Vector3(-10,0,0)
		Globals.OBJ_Spawner.spawn([25,pos])


###PLAYER LAVA DAMAGE###
func _on_lava_hitbox_body_entered(body):
	if body.has_node("%BossFight"):
		body.get_node("%BossFight").is_burning = true
		body.get_node("%BossFight").burning()
func _on_lava_hitbox_body_exited(body):
	if body.has_node("%BossFight"):
		body.get_node("%BossFight").is_burning = false

## LAVA RISING ## 

func lava_rising(boss_hp):
	if lava_level == 0 and boss_hp < 50:
		lava_level = 1
		lava_height_anim.play("raise_1")
	elif lava_level == 1 and boss_hp < 20:
		lava_level = 2
		lava_height_anim.play("raise_2")

func lava_sinking():
	if lava_level == 1:
		lava_height_anim.play("lower_1")
	elif lava_level == 2:
		lava_height_anim.play("lower_2")

## DELETE PRISON ##
func delete_prison():
	await get_tree().create_timer(25.0).timeout
	var prison = get_tree().get_first_node_in_group("Prison")
	if prison: prison.queue_free()

## FIGHT LOST ##
func boss_fight_lost():
	Globals.boom_box_boss_fight = -1
	Globals.fade_player_bg()
	can_attack = false
	dice.hide()
	weird_dice.hide()
	$Extras.hide()

## BOSS KILLED CHECK ##
func kild():
	if killed: return true
	else: return false


func directly_spawned_check():
	var prison_node_check = get_tree().get_first_node_in_group("Prison")
	if prison_node_check == null:
		start_boss_fight() ##for testing when spawning the node 
		var s_m = Globals.my_player.get_node("Movement State Machine")
		s_m.on_child_transition(s_m.current_state, "BossFight")
		
		Globals.set_sky_c(["df0000", -1])
		Globals.set_sky_c(["071a40", 0])
		Globals.set_sky_c(["071a40", 1])
		Globals.set_sky_c(["20165f", 2])
		Globals.set_sky_f([8 , -1])
		Globals.set_sky_f([5 , 0])
		Globals.set_sky_f([5 , 2])

func boom_box_crab():
	Globals.boom_box_boss_fight = 10
	
	Globals.fade_player_bg(false)
	
	if multiplayer.is_server():
		var pos = Vector3(0,1.55,15)
		Globals.OBJ_Spawner.spawn([57,pos])

