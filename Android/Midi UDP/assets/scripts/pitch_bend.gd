extends Resource
class_name PitchBend
@export var time: float
@export var value: int 
func _init(_time: float, _value: int):
	time = _time
	value = _value
