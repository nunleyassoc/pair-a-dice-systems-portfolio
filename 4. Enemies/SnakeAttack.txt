# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

class_name SnakeAttack
extends State

@onready var Snake : RigidBody3D = $"../.."
@onready var SnakeScript : Node = $"../../SnakeScript"
@onready var SnakeMesh: Node3D = $"../../SnakeMesh"

var time_till_attack: float = 5.0
var in_attack = false


## Animated poison on teeth
@onready var poison_anim = $"../../SnakeMesh/Armature_007/Skeleton3D/tooth1/PoisonAnim"
@onready var pb1 = $"../../SnakeMesh/Armature_007/Skeleton3D/tooth1/BallHider/PoisonBall1"
@onready var pb2 = $"../../SnakeMesh/Armature_007/Skeleton3D/tooth2/BallHider2/PoisonBall2"

## Rigid Body balls
@onready var poison_ball_1 = $"../../PoisonBall1"
@onready var poison_ball_2 = $"../../PoisonBall2"

## GPU Particles
@onready var poison_ball_explosion_1 = $"../../PoisonBallExplosion1"
@onready var poison_ball_explosion_2 = $"../../PoisonBallExplosion2"


func Enter():
	$"../../SnakeHissShort".play()
	
	in_attack = true
	time_till_attack = 0.0
	$"../../held_thrown".MAX_VELOCITY = 4.5
	$"../../SnakeMesh/AnimationPlayer".speed_scale = 1.05
	$"../../SnakeMesh/RunParticles".emitting = true

func Exit():
	in_attack = false
	$"../../SnakeMesh/AnimationPlayer".speed_scale = 1.00

func Update(delta):
	time_till_attack -= delta
	
	if time_till_attack < 0:
		time_till_attack = 4.0
		poison_anim.play("ShootPoisonRun_3")

func Physics_Update(_delta):
	if SnakeScript.look_at_player == null:
		Transitioned.emit(self, "SnakeIdle")
	else:
		follow()

func follow():
	var dir = (SnakeScript.look_at_player.global_position - Snake.global_transform.origin).normalized()
	dir.y = -0.25
	Snake.apply_central_force(dir * 20.0)

func spit_poison(left_side:bool = false):
	if not in_attack: return
	if SnakeScript.look_at_player == null: return
	
	var ball
	
	if left_side:
		ball = $"../../PoisonBall1"
		ball.global_position = pb1.global_position
	else:
		ball = $"../../PoisonBall2"
		ball.global_position = pb2.global_position
	
	ball.show()
	ball.freeze = false
	ball.linear_velocity = Vector3(0,0,0)
	ball.angular_velocity = Vector3(0,0,0)
	ball.get_child(0).play("grow")
	
	var dir = (SnakeScript.look_at_player.global_position - ball.global_transform.origin).normalized()
	dir.y += 0.35
	ball.apply_central_impulse(dir * 9.5)

func _on_poison_ball_1_body_entered(body):
	ball_hit(body, poison_ball_1, true)
func _on_poison_ball_2_body_entered(body):
	ball_hit(body, poison_ball_2, false)
 
func ball_hit(player, ball, gpu):
	if player is CharacterBody3D: damage_player(player)
	explode_ball(ball, gpu)

func explode_ball(ball, gpu):
	var particles
	if gpu: particles = poison_ball_explosion_1
	else: particles = poison_ball_explosion_2
	
	particles.global_position = ball.global_position
	particles.emitting = true
	particles.get_child(0).play() #sfx
	
	ball.hide()
	ball.freeze = true
	ball.linear_velocity = Vector3(0,0,0)
	ball.angular_velocity = Vector3(0,0,0)
	ball.global_position = Vector3(0,-25,-3)


func damage_player(player):
	if player.has_node("%HPBar"):
		var hp_node = player.get_node("%HPBar")
		hp_node.take_damage(0.3, false)
		await get_tree().create_timer(1.0).timeout
		
		if player.snake_necklace: return
		
		hp_node.take_damage(0.75, false)
		await get_tree().create_timer(1.0).timeout
		hp_node.take_damage(0.75, false)
