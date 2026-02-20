extends Node
class_name SequencerEngine
var original_bpm : int = 120
var loaded_song : Array[NoteEvent] = []
var cached_record : Array[NoteEvent] = []
var input_buffer : Array[NoteEvent] = []
var buffer_start_t : float = 0.0
var loaded_song_t_ms : float = 0.0
var record_start_t : float = 0.0
var channel : int = 0

var playback_start_t : float = 0.0
var playback_ch : int = 0
var playback_t : float = 0.0
var playback_anim_t : float = 0.0
var playback_index : int = 0
var current_t : float = 0.0
var global_t : float = 0.0
var current_beat : int = 0
var signature_1 : int = 0
var signature_2 : int = 0
var bpm : int = 0


var metronome : Timer
@export var metronome_player : AudioStreamPlayer
@export var tick_sfx : AudioStream
@export var tock_sfx : AudioStream
@export var buffer_end_t : float = 100.0 
@export var animation_anticipation : float = 2000.0 

# All time units are based in miliseconds with float acurracy.
# Update must be called in process and be provided with delta.

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
enum AnimationState {
	WAIT,
	PLAYING
}
var animation_start_t : float = 0.0
var animation_index : int = 0
var animation_state : AnimationState = AnimationState.WAIT
var pending_state : PlaybackState = PlaybackState.IDLE
var playback_state : PlaybackState = PlaybackState.IDLE
var playback_mode : PlaybackMode = PlaybackMode.NONE

var looping : bool = false
var auto_stop : bool = false
var metronome_bool : bool = false
var paused : bool = false

signal send_note(note : int,on_off : bool , channel : int)
signal send_animation(note : int,on_off : bool , channel : int)

func setup_metronome(streamplayer : AudioStreamPlayer,tick : AudioStream, tock : AudioStream, bpm_, Numerator : int, Denominator : int):
	metronome_player = streamplayer
	tick_sfx = tick
	tock_sfx = tock
	bpm = bpm_
	signature_1 = Numerator
	signature_2 = Denominator
	metronome = Timer.new()
	add_child(metronome)
	metronome.wait_time = 60.0/bpm
	metronome.connect("timeout",_Metronome_timeout)
func update(delta : float):
	var scaled_delta = delta * bpm / original_bpm
	global_t += scaled_delta * 1000
	if not paused:
		current_t += scaled_delta * 1000 # miliseconds
	handle_states()
	_anim_playback()
	#print(loaded_song)
	#print(playback_index)
func handle_states():
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
	if loaded_song == []:
		original_bpm = bpm
		set_playback_mode(PlaybackMode.FIRST_RECORD)
	else:
		set_playback_mode(PlaybackMode.OVERDUB)
func finish_recording():
	if playback_mode ==  PlaybackMode.FIRST_RECORD:
		loaded_song_t_ms = current_t - record_start_t
	set_playback_state(PlaybackState.IDLE)

func set_looping(value : bool):
	looping = value

func clear_song():
	cached_record = []
	loaded_song = []
	set_playback_state(PlaybackState.IDLE)

func init_recording():
		loaded_song += cached_record
		cached_record = []
		loaded_song.sort_custom(func(a, b): return a.time < b.time)

func start_playback():
	pending_state = PlaybackState.PLAYING
	set_playback_state(PlaybackState.COUNT_IN)
func stop_playback():
	set_playback_state(PlaybackState.IDLE)

func set_pause(pause : bool):
	if pause:
		paused = true
	else:
		paused = false

func set_channel(channel_ : int):
	channel = channel_

func set_metronome(active : bool, bpm_ : int, Numerator : int, Denominator : int):
	bpm = bpm_
	metronome.wait_time = 60.0/bpm
	signature_1 = Numerator
	signature_2 = Denominator
	metronome_bool = active
	if active:
		metronome.start()
	else:
		metronome.stop()

func handle_note(note : int,on_off : bool):
	if playback_state == PlaybackState.RECORDING:
		cached_record.append(NoteEvent.new(on_off,note,current_t - record_start_t,channel))
	input_buffer.append(NoteEvent.new(on_off,note,global_t,channel))
	if input_buffer == []: 
		buffer_start_t = global_t
		buffer_end_t += global_t
	else:
		if global_t >= buffer_end_t:
			input_buffer = []
func set_playback_state(state : PlaybackState):
	playback_state = state
	match state:
		PlaybackState.IDLE:
			playback_index = 0
			playback_start_t = current_t
		PlaybackState.COUNT_IN:
			current_beat = 0
			if metronome.is_stopped() : metronome.start()
			#here
			animation_index = 0
			var delay = (metronome.wait_time * 1000) * signature_1
			animation_start_t = current_t + delay - animation_anticipation
			animation_state = AnimationState.PLAYING
		PlaybackState.PLAYING:
			init_recording()
			playback_index = 0
		PlaybackState.RECORDING:
			playback_index = 0
			record_start_t = current_t 
func set_playback_mode(mode : PlaybackMode):
	playback_mode = mode
	match mode:
	
		PlaybackMode.OVERDUB:
			init_recording()
	
		PlaybackMode.OVERRIDE:
			init_recording()

func _anim_playback():
	if loaded_song_t_ms <= 0:
		return
	var current_playback_t : float = current_t - animation_start_t
	if loaded_song != []:
		while animation_index < loaded_song.size():
			var event = loaded_song[animation_index]
			
			if current_playback_t >= event.time:
				if event.note_state:
					emit_signal("send_animation", event.note,event.note_state,event.channel)
				animation_index += 1
			else:
				break
		if current_t - playback_start_t >= loaded_song_t_ms:
			if looping:
				animation_index = 0
			else:
				animation_state = AnimationState.WAIT
func _playback():
	if not current_t > animation_start_t:
		pass
	if loaded_song_t_ms <= 0:
		return
	
	var current_playback_t : float = current_t - playback_start_t# - animation_anticipation
	
	if loaded_song != []:
	
		while playback_index < loaded_song.size(): #and current_playback_t <= loaded_song_t_ms:
			var event = loaded_song[playback_index]
			
			if current_playback_t >= event.time :
				if event.note_state:
					emit_signal("send_note", event.note,event.note_state,event.channel)
				playback_index += 1
			else:
				break
			
			var atleast_one_good : bool = false
			for i in input_buffer:
				if i.note == event.note: atleast_one_good = true
				set_pause(atleast_one_good)
			
		if current_t - playback_start_t >= loaded_song_t_ms:
			if looping:
				playback_index = 0
				animation_index = 0
				playback_start_t = current_t
				init_recording()
				if playback_state == PlaybackState.RECORDING:
					record_start_t = current_t
				
			else:
				set_playback_state(PlaybackState.IDLE)
				init_recording()


func _Metronome_timeout() -> void:
	if pending_state != PlaybackState.IDLE:
		if current_beat == signature_1: 
			if !metronome_bool : metronome.stop()
			playback_start_t = current_t
			set_playback_state(pending_state)
			pending_state = PlaybackState.IDLE
	if current_beat == signature_1:
		current_beat = 0
	if current_beat == 0:
		metronome_player.stream = tick_sfx
	else:
		metronome_player.stream = tock_sfx
	metronome_player.play()
	current_beat += 1
