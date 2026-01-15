# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

extends Sprite3D

signal zero_hp
signal took_damage

@export var max_hp: int = 100
@export var real_value : float

###Time inbetween when damage can't be taken###
@export var damage_timeout := 0.5
var can_take_damage := true
var invincible:= false

###Player###
@export var player_HPBar : bool
@export var hp_gears : Control
@export var damage_sfx : AudioStreamPlayer
var armor : float = 0.00

###Sends RPC###
@export var send_to_others : bool

###Emits Particles when hit###
@export var hit_particles : bool
@export var hit_particles_node : GPUParticles3D


func _ready():
	$SubViewport/HealthBar/HealthBar.max_value = max_hp
	$SubViewport/HealthBar/HealthBar.value = max_hp
	real_value = max_hp

func take_damage(damage: float, cause_timeout: bool = true):
	#make a check so it doesn't keep sending rpcs whenever the poor guy is already dead
	#if it was just hit, don't take more damage
	if real_value <= 0.1 or not can_take_damage or invincible:
		return
	#For player HP, Make sure the it's the player in charge
	if player_HPBar and not get_parent().is_multiplayer_authority():
		return
	else:
		damage = damage * (1 - armor)
	
	took_damage.emit()
	
	can_take_damage = false
	real_value -= damage
	
	if send_to_others: send_hp.rpc(real_value, cause_timeout)
	
	if player_HPBar:
		hp_gears.taken_damage(real_value)
		damage_sfx.play()
		$"../../../../..".emit_particles.rpc(2)
	
	if hit_particles: emit_particles()
	
	create_tween().tween_property($SubViewport/HealthBar/HealthBar, "value", real_value, 0.25) #3D
	
	if real_value <= 0.1: zero_hp.emit()
	
	if cause_timeout:
		await get_tree().create_timer(damage_timeout).timeout
	
	can_take_damage = true

@rpc("any_peer","call_remote","reliable")
func send_hp(sent_hp, cause_timeout: bool = true):
	if real_value == sent_hp:
		return
	else:
		can_take_damage = false
		real_value = sent_hp
		create_tween().tween_property($SubViewport/HealthBar/HealthBar, "value", real_value, 0.25) #3D
		
		if real_value <= 0.1:
			zero_hp.emit()
		
		if cause_timeout:
			await get_tree().create_timer(damage_timeout).timeout
		
		can_take_damage = true


func emit_particles():
	hit_particles_node.emitting = true


func heal(added_hp: float = 0.00):
	if not is_multiplayer_authority(): return
	if real_value <= 0.1: return #dont heal if dead:
	
	real_value = min(max_hp, real_value + added_hp) #stops overheal
	create_tween().tween_property($SubViewport/HealthBar/HealthBar, "value", real_value, 0.25) #3D
	hp_gears.taken_damage(real_value)
	
	if send_to_others:
		send_hp.rpc(real_value)


func revive():
	if not is_multiplayer_authority(): return
	
	real_value = 5
	create_tween().tween_property($SubViewport/HealthBar/HealthBar, "value", real_value, 1.5) #3D 
	hp_gears.taken_damage(real_value)
	invincible = true
	await get_tree().create_timer(4.0).timeout
	invincible = false
	
	if send_to_others:
		send_hp.rpc(real_value)

func inc_max_hp(added_max_hp):
	max_hp += added_max_hp
	$SubViewport/HealthBar/HealthBar.max_value = max_hp
	heal(added_max_hp)

func is_at_max_hp():
	if max_hp == real_value: return true
	else: return false
