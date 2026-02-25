extends Area2D

@export var item_data: ItemData
@export var amount: int = 1

@onready var sprite = $Sprite2D

func _ready():
	if item_data and item_data.icon:
		sprite.texture = item_data.icon

func _on_body_entered(body):
	pass
