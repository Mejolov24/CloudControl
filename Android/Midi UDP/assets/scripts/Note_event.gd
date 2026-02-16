extends Resource
class_name NoteEvent
@export var note_state : bool = false
@export var pitch : int = 60
@export var time : float = 0.0
@export var velocity : int = 127
func _init(_note_state : bool = false, _pitch: int = 60, _time: float = 0.0, _velocity: int = 127):
	note_state = _note_state
	pitch = _pitch
	time = _time
	velocity = _velocity
