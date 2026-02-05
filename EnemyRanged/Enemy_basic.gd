extends CharacterBody2D

@onready var anim_player = $EnemyAnimation
@onready var sprite = $EnemySprite
@onready var pivot = $Pivot
@onready var floorDetector = $Pivot/FloorDetect
@onready var wallDetector = $Pivot/WallDetect
@onready var markerArrow = $Pivot/Marker
@onready var areaDetection = $Pivot/AreaDetection

var arrowScene = preload("res://EnemyRanged/EnemyArrow.tscn")
var target = null
var attackRange = 100.0 #satuannya pixel
var hpEnemy = 30.0

var current_state = state.Idle
enum state { Idle, Walk, Attack, GetHit, Death }

const speed = 70
const jumpVelocity = -400.0

func _ready() -> void:
	#target = get_tree().get_first_node_in_group("player")
	pass

func _physics_process(delta: float) -> void:
	#logika gerak dasar
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# biar animasi gethit bisa 
	if current_state == state.GetHit or current_state == state.Death:
		move_and_slide()  #kalau ada efek knocbak nanti 
		update_state()
		return 
	
	if target != null:
		#var direction = (target.position - position).normalized()
		var distance = global_position.distance_to(target.global_position) #jarak real time
		#make fungsi distance_to()
		var directionX = sign(target.global_position.x - global_position.x)
		#print("nilai dari directionX : ", directionX)
		
		if directionX != 0:
			#sprite.flip_h = directionX < 0
			#
			#floorDetector.position.x = abs(floorDetector.position.x) * directionX
			#wallDetector.scale.x = directionX
			#kanan (1) -> scale.x = 1, kiri (-1)
			
			pivot.scale.x = directionX
		
		if distance <= attackRange :#kalau deket serang
			velocity.x = 0
			current_state = state.Attack
			#fire()
		else : #kejar
			velocity.x = directionX * speed
			current_state = state.Walk
			
			if is_on_floor():
				var cliffAhead = not floorDetector.is_colliding() #lubang
				var wallAhead = wallDetector.is_colliding()
				
				if cliffAhead or wallAhead:
					velocity.y = jumpVelocity
				#if wallAhead: velocity.x = 0
			
	else : 
		#kalau g ada player
		velocity.x = 0
		current_state = state.Idle
			
	move_and_slide()
	
	
	#update state berdasar kondisi
	update_state()
	
	#mainkan animasi state skrg
	
func update_state():
	if current_state == state.Death:
		return
		
	match current_state:
		state.Idle: anim_player.play("Idle")
		state.Walk: anim_player.play("Walk")
		state.Attack: anim_player.play("Attack")
		state.GetHit: anim_player.play("GetHit")
		
	if not is_on_floor() and current_state == state.Walk:
		#print("melayang wok")
		pass

func _on_area_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
	pass # Replace with function body.

func _on_area_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
	pass # Replace with function body.

func fire():
	var arrow = arrowScene.instantiate()
	arrow.global_position = markerArrow.global_position
	#arrow.global_rotation = markerArrow.global_rotation
	
	if pivot.scale.x > 0:
		arrow.set_direction(Vector2.RIGHT)
	else :
		arrow.set_direction(Vector2.LEFT)
	
	get_tree().root.add_child(arrow)
	pass
	
func take_damage(amount):
	hpEnemy -= amount
	print("sisa hp enemy : ", hpEnemy)
	
	if hpEnemy <= 0:
		#print("mokad")
		current_state = state.Death
		#$EnemyCollision.set_deferred("disabled", true)
		areaDetection.monitoring = false
	else :
		print("harusnya animasi gethurt")
		current_state = state.GetHit
		velocity = Vector2.ZERO
	pass

func _on_enemy_animation_animation_finished(anim_name: StringName) -> void:
	if anim_name == "GetHit":
		current_state = state.Idle
	if anim_name == "Death":
		queue_free()
	pass # Replace with function body.
