extends Node
class_name SequencerEngine
var loaded_song : Array[NoteEvent] = []
var loaded_song_t_ms : float = 0.0
var record_start_t : float = 0.0
var channel : int = 0

var playback_start_t : float = 0.0
var playback_ch : int = 0
var playback_t : float = 0.0
var playback_anim_t : float = 0.0
var playback_index : int = 0
var current_t : float = 0.0
var current_beat : int = 0
var signature_1 : int = 0
var signature_2 : int = 0
var bpm : int = 0

var metronome : Timer
@export var metronome_player : AudioStreamPlayer
@export var tick_sfx : AudioStream
@export var tock_sfx : AudioStream



enum PlaybackState {
	IDLE,
	COUNT_IN,
	PLAYING,
	RECORDING
}
enum PlaybackMode {
	NONE, # no loop defined yet or just listening
	FIRST_RECORD,  # defining loop length
	OVERDUB,  # layer on top
	OVERRIDE,  # replace loop content
	TRAINING    # special evaluation mode
}
var pending_state : PlaybackState = PlaybackState.IDLE
var playback_state : PlaybackState = PlaybackState.IDLE
var playback_mode : PlaybackMode = PlaybackMode.NONE
var looping : bool = false
var auto_stop : bool = false

signal send_note(note : int,on_off : bool , channel : int)

func _ready() -> void:
	metronome = Timer.new()
	add_child(metronome)
	metronome.connect("timeout",_Metronome_timeout)

func update(time : float):
	current_t = time
	handle_states()

func handle_states():
	if pending_state != PlaybackState.IDLE:
		if current_beat == signature_1: 
			set_playback_state(pending_state)
			pending_state = PlaybackState.IDLE
	match playback_state:
		PlaybackState.RECORDING:
			if playback_mode != PlaybackMode.FIRST_RECORD:
				_playback()
		PlaybackState.PLAYING:
			if loaded_song != []:
				_playback()

func start_recording():
	record_start_t = current_t
	pending_state = PlaybackState.RECORDING
	set_playback_state(PlaybackState.COUNT_IN)
func finish_recording():
	if playback_mode ==  PlaybackMode.FIRST_RECORD:
		loaded_song_t_ms = current_t - record_start_t

func set_channel(channel_ : int):
	channel = channel_

func set_metronome(active : bool, bpm_ : int, Numerator : int, Denominator : int):
	bpm = bpm_
	metronome_player.wait_time = 60.0/bpm
	signature_1 = Numerator
	signature_2 = Denominator
	if active:
		metronome_player.start()
	else:
		metronome_player.stop()

func handle_note(note : int,on_off : bool):
	if playback_state == PlaybackState.RECORDING:
		loaded_song.append(NoteEvent.new(on_off,note,current_t - record_start_t,channel))

func set_playback_state(state : PlaybackState):
	playback_state = state
	match state:
		PlaybackState.IDLE:
			playback_index = 0
			playback_start_t = current_t
		PlaybackState.COUNT_IN:
			current_beat = 0
			if metronome_player.is_stopped() : metronome_player.start()
		PlaybackState.PLAYING:
			loaded_song.sort_custom(func(a, b): return a.time < b.time)
			playback_start_t = current_t
			playback_index = 0
		PlaybackState.RECORDING:
			record_start_t = current_t
			playback_start_t = current_t
			playback_index = 0
func set_playback_mode(mode : PlaybackMode):
	playback_mode = mode
	match mode:
	
		PlaybackMode.OVERDUB:
			loaded_song.sort_custom(func(a, b): return a.time < b.time)
	
		PlaybackMode.OVERRIDE:
			loaded_song.sort_custom(func(a, b): return a.time < b.time)


func _playback():
	if playback_state != PlaybackState.PLAYING and playback_state != PlaybackState.RECORDING:
		return
	if loaded_song_t_ms <= 0:
		return
	
	var current_playback_t : float = current_t - playback_start_t
	
	if loaded_song != []:
		while playback_index < loaded_song.size():
			var event = loaded_song[playback_index]
			if current_playback_t >= event.time:
				if event.note_state:
					emit_signal("send_note", event.note,true,event.channel)
				else:
					emit_signal("send_note", event.note,false,event.channel)
				playback_index += 1
			else:
				break
		if current_t - playback_start_t >= loaded_song_t_ms:
			if looping:
				playback_index = 0
				playback_start_t = current_t
			else:
				set_playback_state(PlaybackState.IDLE)

func _Metronome_timeout() -> void:
	if current_beat == signature_1:
		current_beat = 0
	if current_beat == 0:
		metronome_player.stream = tick_sfx
	else:
		metronome_player.stream = tock_sfx
	metronome_player.play()
	current_beat += 1
