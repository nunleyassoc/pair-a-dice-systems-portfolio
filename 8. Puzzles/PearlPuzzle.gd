# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Puzzle the player collects Pearls. Cool!

extends Node

@onready var clock_hand = $"../Clock/FloorTimerFloor/ClockHand"
@onready var clock_audio = $"../Clock/FloorTimerFloor/ClockHand/ClockHand/ClockAudio"

var rotation_tween: Tween

var attempt = 0
var completed = false

func start_puzzle():
	start_clock()
	show_pearls()

func show_pearls():
	for pearl in $"../Pearls".get_children():
		await get_tree().create_timer(0.1).timeout
		pearl.pearl_up()

func start_clock():
	attempt += 1
	var current_attempt = attempt
	
	clock_audio.pitch_scale = 1.0
	clock_audio.play()
	
	var size = get_tree().get_nodes_in_group("Player").size()
	var clock_time = 45.0 - size * 3.0 #set timer
	
	#rotate clock
	rotation_tween = create_tween()
	rotation_tween.tween_property(clock_hand, "rotation_degrees", Vector3(0,-360,0), clock_time).from(Vector3(0,0,0))
	
	await get_tree().create_timer(clock_time - 4.00).timeout
	#show pearls are about to go away
	pearls_going_away()
	
	if current_attempt != attempt: return
	if completed: return
	
	await get_tree().create_timer(4.00).timeout
	
	if current_attempt != attempt: return
	if completed: return
	
	clock_hand.rotation_degrees = Vector3.ZERO #quick reset
	
	check_pearls_final()


func pearls_going_away():
	for pearl in $"../Pearls".get_children():
		if not pearl.pearl_collected:
			pearl.going_away()
	
	##sound
	var clock_sound = clock_audio
	create_tween().tween_property(clock_sound, "pitch_scale", 1.25, 1.0)


func check_pearls(emit_sound):
	var pearls_collected = 0
	var pearls_sounds_index = 0
	
	for pearl in $"../Pearls".get_children():
		if pearl.pearl_collected:
			pearls_collected += 1
			
			if pearl.emits_sound:
				pearls_sounds_index += 1
	
	if emit_sound:
		Globals.my_player.get_node("%Pearls").play_pearl_sound(pearls_sounds_index-1)
	
	if pearls_collected >= $"../Pearls".get_children().size():
		puzzle_success()

func check_pearls_final():
	
	var pearls_collected = 0
	
	for pearl in $"../Pearls".get_children():
		if pearl.pearl_collected:
			pearls_collected += 1 #increment
		
		pearl.pearl_collected = false #reset
	
	#print("SIZE: ", str($"../Pearls".get_children().size()), " VS COLLECTED: ", str(pearls_collected))
	
	if pearls_collected >= $"../Pearls".get_children().size():
		puzzle_success()
	else:
		puzzle_fail()


func puzzle_success():
	if completed: return
	attempt += 1
	completed = true
	
	get_parent().free_map = true
	get_parent().free_treasure_map()
	
	if rotation_tween: # clock hand
		rotation_tween.kill() #clock hand stops
	
	clock_audio.stop()

func puzzle_fail():
	attempt += 1
	$"../TreasureMapBox/Failed".play()
	clock_audio.stop()
	
	if rotation_tween: # clock hand
		rotation_tween.kill() #clock hand stops
	
	$"../Button/ButtomAnim".play("up")
	await get_tree().create_timer(0.2).timeout
	get_parent().puzzle_in_progress = false

