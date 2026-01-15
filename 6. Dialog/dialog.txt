# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## Simple Dialog System that shows one letter at a time.
## Dialog System Features
## \\1.0 waits 1 sec or \\3.2 to wait 3.2 seconds
## \\f fades the text out, used at the end of a sentence\\f
## \\p[command] could be used to call a function

##EXAMPLES:

## "ss_dice_unk_neutral_3": "Does that sound\\0.1.\\0.1.\\0.1. fair?\\0.75\\f",
## "ss_dice_unk_neutral_4": "\\p[final_dia]We'll see you there\\0.75\\f",
## "prison_dice_unk_neutral_0": "\\p[Up]LOOK!\\0.75 THEY LED US\nTO THE LAST GEMS!\\1.5",
## "prison_dice_unk_neutral_2": "\\p[end_dia]TIME TO ACCEPT YOUR FATE\\1\nTHERES NOWHERE TO HIDE\\1",


extends Label3D

@export var Creature_Name: String = "crab"

signal dialog_finished
signal dialog_signal(value)

@export var typing_speed := 0.05  # Speed of typewriter effect
var erase_speed := 0.01   # Speed of death reverse effect
var current_text := ""
var is_typing := false
var is_alive := true
var dialog_id := 0 # stops overlapping dialogs

var look_at_rand_dialog = false # play a random look at dialog

@export var bleeps: AudioStreamPlayer3D
@export var min_bleep_length: float = 0.0
@export var max_bleep_length: float = 0.05
var bleep_queued := false

@export var look_talkable:bool = true

func _ready():
	text = ""

func look_talk():
	if not is_typing and look_talkable:
		var line = DialogManager.get_dialog( Creature_Name )
		display_text(line)

func basic_talk():
	var line = DialogManager.get_dialog( Creature_Name )
	display_text(line)

func display_text(new_text: String):
	dialog_id += 1
	current_text = new_text
	text = ""
	is_typing = true
	
	_start_typewriter_effect(dialog_id)


func _start_typewriter_effect(id: int):
	var text_to_show = ""
	var i = 0
	
	while i < current_text.length():
		if not is_alive or id != dialog_id: return
		
		var next_char = current_text[i]
		
		if next_char == "\\":
			var result = _handle_escape_sequence(current_text, i)
			
			if result.has("pause_duration"): ##PAUSE DIA
				i = result["new_index"]
				await get_tree().create_timer(result["pause_duration"]).timeout
				if id != dialog_id or not is_alive: return
				continue
			
			elif result.has("command"):
				match result["command"]:
					"f": ##FADE OUT
						i = result["new_index"]
						text_to_show = ""
						await fade_text()
						continue
						
					"X", "Y", "Z", "V", "W":
						i = result["new_index"]
						text_to_show += DialogManager.get_stat_value(result["command"])
						text = text_to_show
						continue
						
					"p": ##Send signal
						i = result["new_index"]
						var value = result.get("signal_value", "")
						emit_signal("dialog_signal", value)
						continue
						
					# You can add more commands here like "s" for sound, "c" for color, etc.
				# if unknown command, just skip it or handle it some other way
				i = result["new_index"]
				continue
			else:
				next_char = "\\"  # fallback if parsing fails
		
		text_to_show += next_char
		
		if bleeps: play_bleeps() #sfx
		
		text = text_to_show
		await get_tree().create_timer(typing_speed).timeout
		
		if id != dialog_id or not is_alive: return
		i += 1
	
	if id == dialog_id:
		is_typing = false
		emit_signal("dialog_finished")


func _handle_escape_sequence(txt: String, index: int) -> Dictionary:
	var i = index + 1
	if i >= txt.length():
		return {}
	
	var next_char = txt[i]
	
	if next_char == "p":
		i += 1
		if i < txt.length() and txt[i] == "[":
			i += 1
			var value := ""
			while i < txt.length() and txt[i] != "]":
				value += txt[i]
				i += 1
			if i < txt.length() and txt[i] == "]":
				i += 1
				return {
					"command": "p",
					"signal_value": value,
					"new_index": i
				}
	
	# Handle fade and dynamic stat insertions
	if next_char in ["f", "X", "Y", "Z", "V", "W", "p"]:
		return {
			"command": next_char,
			"new_index": i + 1
		}
	
	# Handle pause like \0.5
	var pause_value := ""
	var dot_found := false
	while i < txt.length():
		var c := txt[i]
		if c == ".":
			if dot_found:
				break
			dot_found = true
			pause_value += "."
		elif c.is_valid_float():
			pause_value += c
		else:
			break
		i += 1
	
	if pause_value.is_valid_float():
		return {
			"pause_duration": pause_value.to_float(),
			"new_index": i
		}
	
	return {}



func understand_creature():
	DialogManager.set_understanding(Creature_Name, 100)

func death():
	is_alive = false
	_erase_text()
	DialogManager.reset_dialog( Creature_Name )

func _erase_text():
	is_typing = true
	for i in range(len(current_text), -1, -1):  # Loop backwards
		text = current_text.substr(0, i)  # Remove one letter at a time
		await get_tree().create_timer(erase_speed).timeout
	
	text = ""  # Ensure it's fully cleared
	is_typing = false

func fade_text():
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "transparency", 1, 0.25).as_relative()
	await fade_tween.finished
	
	text = ""
	transparency = 0

func play_bleeps():
	if bleeps:
		if not bleeps.is_playing() and not bleep_queued:
			bleep_queued = true
			
			var rand_wait = randf_range(min_bleep_length,max_bleep_length)
			
			await get_tree().create_timer(rand_wait).timeout
			bleeps.play()
			bleep_queued = false

