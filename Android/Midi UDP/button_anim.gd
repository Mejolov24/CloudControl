extends Control
var tween : Tween 
var duration : float = 2.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animate_preview()


func animate_preview():
	print("animating")
	tween = create_tween()
	tween.tween_property($outline,"scale",Vector2(1,1),duration)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property($outline,"modulate:a",0,0.4)
	#owner.handle_sound()
