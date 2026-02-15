extends Node2D

signal particle_finished

@export var lifetime: float = 1.0
@export var particle_count: int = 12
@export var spread_radius: float = 30.0
@export var particle_color: Color = Color.GREEN

var particles: Array = []

func _ready():
	_spawn_particles()
	
	var lifetime_timer = get_tree().create_timer(lifetime)
	lifetime_timer.timeout.connect(_on_lifetime_finished)

func _spawn_particles():
	for i in range(particle_count):
		var particle = _create_particle()
		var angle = (TAU / particle_count) * i
		var offset = Vector2(cos(angle), sin(angle)) * randf_range(10, spread_radius)
		
		particle.position = offset
		add_child(particle)
		particles.append(particle)
		
		_animate_particle(particle)

func _create_particle() -> Sprite2D:
	var sprite = Sprite2D.new()
	
	var size = 12
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = size / 2.0
	var thickness = 3
	
	for y in range(size):
		for x in range(center - thickness / 2.0, center + thickness / 2.0 + 1):
			if x >= 0 and x < size:
				image.set_pixel(x, y, particle_color)
	
	for x in range(size):
		for y in range(center - thickness / 2.0, center + thickness / 2.0 + 1):
			if y >= 0 and y < size:
				image.set_pixel(x, y, particle_color)
	
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	sprite.modulate = Color(particle_color.r * 0.3, particle_color.g, particle_color.b * 0.3, 1.0)
	
	return sprite

func _animate_particle(particle: Sprite2D):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "position:y", particle.position.y - 50, lifetime)
	tween.tween_property(particle, "modulate:a", 0.0, lifetime)

func _on_lifetime_finished():
	particle_finished.emit()
	queue_free()
