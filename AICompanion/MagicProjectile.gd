extends Area2D

signal projectile_hit(target, damage)
signal projectile_missed
signal projectile_expired

@export var speed: float = 300.0
@export var damage: int = 15
@export var lifetime: float = 3.0
@export var homing_strength: float = 3.0
@export var rotate_projectile: bool = true
@export var projectile_color: Color = Color(0.3, 0.7, 1.0)

var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null
var velocity: Vector2 = Vector2.ZERO

@onready var sprite: Variant = $AnimatedSprite2D if has_node("AnimatedSprite2D") else ($Sprite2D if has_node("Sprite2D") else null)
@onready var particles: CPUParticles2D = $Particles if has_node("Particles") else null
@onready var lifetime_timer: Timer = Timer.new()

func _ready():
	add_to_group("projectiles")
	add_to_group("companion_projectiles")
	
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = false
	
	body_entered.connect(_on_body_entered)
	
	_setup_lifetime_timer()
	_setup_visuals()
	
	velocity = direction.normalized() * speed

func _setup_lifetime_timer():
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	add_child(lifetime_timer)
	lifetime_timer.start()

func _setup_visuals():
	if sprite:
		if sprite is AnimatedSprite2D:
			sprite.play()
		sprite.modulate = Color(projectile_color.r * 1.5, projectile_color.g * 1.0, projectile_color.b * 2.0)
	else:
		_create_default_sprite()
	
	if particles:
		particles.emitting = true

func _create_default_sprite():
	sprite = Sprite2D.new()
	add_child(sprite)
	
	var size = 16
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x - size / 2.0, y - size / 2.0).length()
			if dist < size / 2.0:
				var alpha = 1.0 - (dist / (size / 2.0))
				var color = Color(projectile_color.r, projectile_color.g, projectile_color.b, alpha)
				image.set_pixel(x, y, color)
	
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	sprite.modulate = Color(projectile_color.r * 1.5, projectile_color.g * 1.0, projectile_color.b * 2.0)

func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		var desired_direction = (target.global_position - global_position).normalized()
		direction = direction.lerp(desired_direction, homing_strength * delta).normalized()
		velocity = direction * speed
	
	global_position += velocity * delta
	
	if rotate_projectile:
		rotation = velocity.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		projectile_hit.emit(body, damage)
		_create_hit_effect()
		queue_free()

func _on_lifetime_expired():
	projectile_expired.emit()
	_explode()

func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()
	velocity = direction * speed

func set_target(new_target: Node2D):
	target = new_target

func set_damage(new_damage: int):
	damage = new_damage

func _explode():
	projectile_missed.emit()
	_create_hit_effect()
	queue_free()

func _create_hit_effect():
	var effect = Node2D.new()
	var sprite_effect = Sprite2D.new()
	
	var size = 24
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x - size / 2.0, y - size / 2.0).length()
			if dist < size / 2.0:
				var alpha = 1.0 - (dist / (size / 2.0))
				var color = Color(projectile_color.r * 0.8, projectile_color.g * 0.9, projectile_color.b, alpha * 0.8)
				image.set_pixel(x, y, color)
	
	var texture = ImageTexture.create_from_image(image)
	sprite_effect.texture = texture
	
	effect.add_child(sprite_effect)
	effect.global_position = global_position
	get_tree().root.add_child(effect)
	
	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_effect, "scale", Vector2(2.5, 2.5), 0.3)
	tween.tween_property(sprite_effect, "modulate:a", 0.0, 0.3)
	tween.finished.connect(effect.queue_free)
