extends Control
var tween : Tween 
@export var animation : PackedScene
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if $ColorRect.material:
		$ColorRect.material = $ColorRect.material.duplicate()
	#animate_preview()

func _on_touch_screen_button_pressed() -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self,"scale",Vector2(1.2,1.2),0.1)
	tween.tween_property($ColorRect,"material:shader_parameter/alpha_multiplier",2,0.05)


func _on_touch_screen_button_released() -> void:
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self,"scale",Vector2(1,1),0.1)
	tween.tween_property($ColorRect,"material:shader_parameter/alpha_multiplier",1,0.1)

func animate_preview(anticipation : float = 2):
	print("animating")
	var scene = animation.instantiate()
	scene.duration = anticipation / 1000
	add_child(scene)
