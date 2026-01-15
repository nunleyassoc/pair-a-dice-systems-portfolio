# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Script is the shell shuffling game. pretty simple stuff.
## Took me 3~ Hours total to impliment + multiplayer and never touch again
## Never have had an issue with this one


extends Node

@onready var clock_hand = $"../Clock/FloorTimerFloor/ClockHand"
@onready var clock_audio = $"../Clock/FloorTimerFloor/ClockHand/ClockHand/ClockAudio"

@onready var button_anim_1 = $"../Stands/Stand1/Button1/ButtonAnim"
@onready var button_anim_2 = $"../Stands/Stand2/Button2/ButtonAnim"
@onready var button_anim_3 = $"../Stands/Stand3/Button3/ButtonAnim"

@onready var clam_anim_1 = $"../Clams/Clam1/ClamAnim"
@onready var clam_anim_2 = $"../Clams/Clam2/ClamAnim"
@onready var clam_anim_3 = $"../Clams/Clam3/ClamAnim"

@onready var pearl_1 = $"../Clams/Clam1/Pearl"
@onready var pearl_2 = $"../Clams/Clam2/Pearl"
@onready var pearl_3 = $"../Clams/Clam3/Pearl"

@onready var clam_mixer: AnimationPlayer = $"../Clams/ClamMixer"

var rotation_tween: Tween

var attempt = 0
var puzzles_completed = 0

var shell_order: Array[bool] = [false, true, false]  # Ball under middle shell

var total_shuffles: int = 0 #10 #
var shuffles_completed: int = 0

var anim_speed: float = 0.75 #1.0 #

var buttons_active = false

var clam_rng = RandomNumberGenerator.new()

func _ready():
	clam_rng.set_seed(Networking.lobby_seed)

func start_puzzle():
	attempt += 1
	#start_clock()
	clam_swap_start()

func start_clock():
	var current_attempt = attempt
	
	clock_audio.pitch_scale = 0.85
	clock_audio.play()
	
	var clock_time = 90.0
	
	#rotate clock
	rotation_tween = create_tween()
	rotation_tween.tween_property(clock_hand, "rotation_degrees", Vector3(0,-360,0), clock_time).from(Vector3(0,0,0))
	
	await get_tree().create_timer(clock_time - 6.00).timeout
	
	if current_attempt != attempt: return #attempt susser
	
	var clock_sound = clock_audio #going away warning sound
	create_tween().tween_property(clock_sound, "pitch_scale", 1.1, 1.0)
	
	await get_tree().create_timer(6.00).timeout
	
	if current_attempt != attempt: return
	
	clock_hand.rotation_degrees = Vector3.ZERO #quick reset
	
	puzzle_fail()

func _on_button_hitbox_1_body_entered(_body):
	if buttons_active and multiplayer.is_server():
		flip_clam.rpc(1)

func _on_button_hitbox_2_body_entered(_body):
	if buttons_active and multiplayer.is_server():
		flip_clam.rpc(2)

func _on_button_hitbox_3_body_entered(_body):
	if buttons_active and multiplayer.is_server():
		flip_clam.rpc(3)

func show_buttons(): #in and out are flipped
	button_anim_1.play("in")
	button_anim_2.play("in")
	button_anim_3.play("in")
	await get_tree().create_timer(0.3).timeout
	buttons_active = true

func hide_buttons():
	buttons_active = false #trusting this
	
	button_anim_1.play("out")
	button_anim_2.play("out")
	button_anim_3.play("out")


func clam_swap_start():
	## Increase Difficulty and reset vars
	total_shuffles += 5
	shuffles_completed = 0
	anim_speed += 0.25
	shell_order = [false, true, false]
	
	pearl_2.show() ## pearl always starts in the middle
	
	## Open the Clams to show Pearl
	clam_anim_1.play("open")
	await get_tree().create_timer(0.25).timeout
	clam_anim_2.play("open")
	await get_tree().create_timer(0.25).timeout
	clam_anim_3.play("open")
	await get_tree().create_timer(3.00).timeout
	
	## Close Clams
	clam_anim_1.play("close")
	clam_anim_2.play("close")
	clam_anim_3.play("close")
	
	await get_tree().create_timer(2.00).timeout
	
	## Start Animations
	var anim_num = str(clam_rng.randi_range(1,14))
	clam_mixer.play(anim_num, -1 ,anim_speed)


func _on_clam_mixer_animation_finished(anim_name):
	if anim_name == "RESET":
		return
	
	if shuffles_completed < total_shuffles: #keep going till total shuffle is reached
		shuffles_completed += 1 
		
		var anim_num = str(clam_rng.randi_range(1,14))
		clam_mixer.play(anim_num, -1 ,anim_speed)
	else:
		clam_swap_guess()

func clam_swap_guess():
	clam_mixer.play("RESET")
	await get_tree().create_timer(0.5).timeout
	show_buttons() ## Player Makes Guess

func swap_two_shells(shell0: int, shell1: int):
	var temp = shell_order[shell0]
	shell_order[shell0] = shell_order[shell1]
	shell_order[shell1] = temp

func swap_three_shells(shell0: int, shell1: int, shell2: int, direction: String):
	if direction == "right_to_left":
		# Cyclic swap from right to left: shell2 -> shell1 -> shell0 -> shell2
		var temp = shell_order[shell0]
		shell_order[shell0] = shell_order[shell2]
		shell_order[shell2] = shell_order[shell1]
		shell_order[shell1] = temp
	elif direction == "left_to_right":
		# Cyclic swap from left to right: shell0 -> shell1 -> shell2 -> shell0
		var temp = shell_order[shell0]
		shell_order[shell0] = shell_order[shell1]
		shell_order[shell1] = shell_order[shell2]
		shell_order[shell2] = temp


@rpc("authority","call_local","reliable")
func flip_clam(clam_num):
	hide_buttons()
	
	## Show correct Pearl
	var pearl_spot = 0
	
	if shell_order[0]:
		pearl_1.show()
		pearl_spot = 1
	elif shell_order[1]:
		pearl_2.show()
		pearl_spot = 2
	elif shell_order[2]:
		pearl_3.show()
		pearl_spot = 3
	
	## Open the Clams
	clam_anim_1.play("open")
	clam_anim_2.play("open")
	clam_anim_3.play("open")
	
	await get_tree().create_timer(5.0).timeout
	
	## Close the Clams
	clam_anim_1.play("close")
	clam_anim_2.play("close")
	clam_anim_3.play("close")
	
	await get_tree().create_timer(2.0).timeout
	
	pearl_1.hide()
	pearl_2.hide()
	pearl_3.hide()
	
	#print("guessed: ", clam_num, " correct: ", pearl_spot)
	
	if clam_num == pearl_spot:
		puzzles_completed += 1
		check_to_continue()
	else:
		puzzle_fail()

func check_to_continue():
	if puzzles_completed > 3:
		puzzle_success()
	else:
		clam_swap_start()


func puzzle_success():
	attempt += 1
	get_parent().free_map = true
	get_parent().free_treasure_map()
	
	if rotation_tween:
		rotation_tween.kill()

func puzzle_fail(): #reset for new attempt
	$"../TreasureMapBox/Failed".play()
	
	clock_audio.stop()
	attempt += 1
	
	if rotation_tween:
		rotation_tween.kill() #clock hand stops
	
	#reset vars
	puzzles_completed = 0
	shell_order = [false, true, false]
	total_shuffles = 0
	anim_speed = 0.75
	shuffles_completed = 0
	
	await get_tree().create_timer(1.00).timeout
	
	$"../Button/ButtomAnim".play("up") #main start button
	get_parent().puzzle_in_progress = false #can start puzzle again now
