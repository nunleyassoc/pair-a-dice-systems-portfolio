# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## Cherry Picked Funcs from my dialog manager, close ties to dialog script

var bosses_killed := 0
var dice_rolled := 0
var enemys_killed := 0
var things_eaten := 0
var hp_healed := 0.0

@export var standing := 0 # Tracks Karma for Dialog Responces

var understanding_data = {}  # Tracks understanding levels for creatures ex: "crab": 100
var dialog_levels := {}  # Tracks dialog level per NPC


func get_dialog(npc_id: String) -> String:
	if npc_id in DIALOG_DATA:
		var understanding = get_understanding(npc_id)
		var standing_key := get_standing()
		var branch_prefix := npc_id
		
		if understanding < 100:
			branch_prefix += "_unk"
		
		var context_key := branch_prefix + standing_key
		var level := get_dialog_level(context_key)
		var key := context_key + "_" + str(level)
		
		if not DIALOG_DATA[npc_id].has(key):
			dialog_levels[context_key] = 0
			key = context_key + "_0"
		
			if not DIALOG_DATA[npc_id].has(key):
				return "[Missing: %s]" % key
		
		advance_dialog(context_key)
		return DIALOG_DATA[npc_id][key]
		
	return "[No dialog for %s]" % npc_id

func advance_dialog(context_key: String):
	dialog_levels[context_key] = get_dialog_level(context_key) + 1

func get_dialog_level(context_key: String) -> int:
	return dialog_levels.get(context_key, 0)

func get_understanding(creature: String) -> int:
	return understanding_data.get(creature, 0)

func set_understanding(creature: String, value: int):
	understanding_data[creature] = value

func reset_dialog(npc_id: String):
	for context_key in dialog_levels.keys():
		if context_key.begins_with(npc_id):
			dialog_levels[context_key] = 0

func reset_context(context_key: String):
	if dialog_levels.has(context_key):
		dialog_levels[context_key] = 0

# Get player global Karma standing
func get_standing() -> String:
	if standing == 0:
		return "_neutral"
	elif standing < 0:
		return "_evil"
	else:
		return "_good"


func get_stat_value(command: String) -> String:
	match command:
		"X":
			return str(bosses_killed)
		"Y":
			return str(dice_rolled)
		"Z":
			return str(enemys_killed)
		"V":
			return str(things_eaten)
		"W":
			return str(hp_healed)
		_:
			return "[?]"