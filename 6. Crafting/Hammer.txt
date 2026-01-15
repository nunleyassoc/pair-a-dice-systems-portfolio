# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Script Controls Crafting
## It's not the easiest to follow, as it references a lot of things like recipies and Ingredients,
## But it was vital to have quick crafting and it did just that.

extends Node

var current_recipe: Recipe
var current_recipe_ingredients: Array[String] = []
var current_recipe_results: Array[String] = []
var ingredients_found: Array[RigidBody3D] = []

var crafting_particle_1_active = false
var crafting_particle_2_active = false
var crafting_particle_3_active = false

@onready var hit_particles_1 = $"../HitParticles"
@onready var hit_particles_2 = $"../HitParticles2"
@onready var hit_particles_3 = $"../HitParticles3"



func _ready():
	get_parent().rotate_y(randi())
	get_parent().rotate_x(randi())
	get_parent().rotate_z(randi())

func selected_recipe(_recipe: Recipe):
	
	if not _recipe.unlocked: return
	
	if current_recipe == null:
		current_recipe = _recipe
		
		for ingredient in current_recipe.ingredients:
			current_recipe_ingredients.append(str(ingredient.name))
			
		for result in current_recipe.results:
			current_recipe_results.append(str(result.name))
		
		$"../FirstCollisionDetector".monitoring = true
		
		await get_tree().create_timer(0.55).timeout
		if current_recipe != null:
			craft_check()
			reset_everything()

func _on_first_collision_detector_body_entered(body):
	if body_check(body):
		if not current_recipe == null and not $"../CraftDetector".monitoring:
			$"../CraftDetector".global_position = body.global_position
			$"../CraftDetector".monitoring = true
			$"../CraftDetector/CraftDetectorAnim".play("IncreaseSize")
			$"../FirstCollisionDetector".call_deferred("set_monitoring", false)

func _on_craft_detector_body_entered(body):
	if body_check(body):
		if ingredients_found.find(body) == -1:
			ingredients_found.append(body)
			craft_check()

func body_check(body):
	if not body.is_in_group("Hammer") and body.is_in_group("OBJ"):
		if not body.get_child(0).held_by_seagull:
			return true
	
	return false

func craft_check():
	if current_recipe == null or ingredients_found.size() < current_recipe.ingredients.size():
		return
	
	var needed: Array[String] = current_recipe_ingredients.duplicate()
	var objs_in_use: Array[StringName] = []
	var avg_position = Vector3()
	
	for ingredient in ingredients_found:
		for item_needed in needed:
			
			if ingredient == null:
				break
			
			if ingredient.has_node("Item Sphere"):
				if ingredient.get_node("Item Sphere").is_in_group(item_needed):
					needed.erase(item_needed)
					objs_in_use.append(ingredient.name)
					avg_position += ingredient.global_position
					
					break
		
		#Good to Go, Craft
		if needed.size() == 0:
			$"../CraftingSound".play()
			
			avg_position /= objs_in_use.size()
			
			if multiplayer.is_server():
				Globals.create_and_destroy(current_recipe_results, objs_in_use, avg_position)
			else:
				Globals.create_and_destroy.rpc_id(1, current_recipe_results, objs_in_use, avg_position)
			
			emit_crafting_particles(avg_position)
			
			for result in current_recipe_results:
				Globals.check_achievement(Globals.temp_match(result))
			
			reset_everything()
			
			if Globals.tutorial:
				get_tree().get_first_node_in_group("Tutorial").crafted()
			
			return

func reset_everything():
	current_recipe = null
	current_recipe_ingredients.clear()
	current_recipe_results.clear()
	ingredients_found.clear()
	
	$"../FirstCollisionDetector".set_deferred("monitoring", false)
	$"../CraftDetector".set_deferred("monitoring", false)
	$"../CraftDetector".global_position.y += 20


## Palm Tree
func _on_first_collision_detector_area_entered(area):
	craft_palm_tree(area)

func _on_craft_detector_area_entered(area):
	craft_palm_tree(area)

func craft_palm_tree(area):
	if area.is_in_group("Palm Tree"):
		if not current_recipe == null:
			if current_recipe.name == "Palm Tree":
				var tree: Array[StringName] = [area.get_parent().name]
				var pos = area.get_parent().global_position + Vector3(0,1,0)
				
				if multiplayer.is_server():
					Globals.create_and_destroy(current_recipe_results, tree, pos)
				else:
					Globals.create_and_destroy.rpc_id(1, current_recipe_results, tree, pos)
				
				$"../CraftingSound".play()
				
				reset_everything()
				
				if Globals.tutorial: get_tree().get_first_node_in_group("Tutorial").crafted()

func emit_crafting_particles(avg_position):
	if not crafting_particle_1_active:
		
		hit_particles_1.global_position = avg_position
		hit_particles_1.emitting = true
		
		crafting_particle_1_active = true
		await get_tree().create_timer(2.0).timeout
		
		crafting_particle_1_active = false
		
	elif not crafting_particle_2_active:
		
		hit_particles_2.global_position = avg_position
		hit_particles_2.emitting = true
		
		crafting_particle_2_active = true
		await get_tree().create_timer(2.0).timeout
		
		crafting_particle_2_active = false
		
	elif not crafting_particle_3_active:
		
		hit_particles_3.global_position = avg_position
		hit_particles_3.emitting = true
		
		crafting_particle_3_active = true
		await get_tree().create_timer(2.0).timeout
		
		crafting_particle_3_active = false
