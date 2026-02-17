extends CanvasLayer
var scales = {
	"chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"major_pentatonic": [0, 2, 4, 7, 9],
	"minor_pentatonic": [0, 3, 5, 7, 10],
	"blues": [0, 3, 5, 6, 7, 10],
	"harmonic_minor": [0, 2, 3, 5, 7, 8, 11]
}
var selected_scale : Array = scales["major"]
var octave : int = 5
var semitone : int = 0
var columns : int = 5
var rows : int = 3
var total_buttons : int = 0
@export var grid : GridContainer
@export var octave_number : Label
@export var columns_text : Label
@export var rows_text : Label
@export var semitone_text : Label
@export var scale_selector : OptionButton
@export var slider : VSlider
@export var record_button : CheckBox
@export var play_button : CheckBox
@export var button_scene : PackedScene
@export var stream_player : PackedScene
@export var button_icons : Array[CompressedTexture2D]
@export var ui_theme : Theme
@export var center : Control
@export var top : Control
@export var top2 : Control
@export var bottom : Control
@export var left : Control
@export var right : Control
@export var color_picker : Control
@export var graphs : Control
@export var settings_buttons : Control
@export var tick : Timer
@export var tock : Timer
@export var tick_sfx : AudioStream
@export var tock_sfx : AudioStream
@export var metronome_player : AudioStreamPlayer
@export var signature_text_1 : Label
@export var signature_text_2 : Label
@export var channel_text_1 : Label
var signature_1 : int = 4
var signature_2 : int = 4
var metronome_enabled : bool = false
var bpm : int = 120
var current_beat : int = 0
var sustain : bool = false
var midi_on : bool = false
var sound : bool = true
var bend_latch : bool = false
var ip_address : String
var port : int = 700
var udp = PacketPeerUDP.new()

var current_channel : int = 0
var current_t : float = 0.0

var sequencer : SequencerEngine

func _ready() -> void:
	grid.add_theme_constant_override("v_separation", 25)
	grid.add_theme_constant_override("h_separation", 25)
	reload_buttons(5,3)
	var all_scale_names = scales.keys()
	for i in range(all_scale_names.size()):
		var scale_name = all_scale_names[i]
		scale_selector.add_item(scale_name)
	scale_selector.select(1)
	
	sequencer = SequencerEngine.new()
	add_child(sequencer)
	sequencer.setup_metronome(metronome_player,tick_sfx,tock_sfx,bpm,signature_1,signature_2)
	sequencer.connect("send_note",recieve_note)
	

var packet_queue : Array = []
var delay_timer : float = 0.0
const DELAY_BETWEEN_PACKETS : float = 0.01

func send_data(data_array: Array):
	if ip_address != "":
		packet_queue.append(data_array)
var hided_grid : bool = false #check if we already tweened menu, used in startup



func _process(delta: float) -> void:
	sequencer.update(Time.get_ticks_msec())
	
	
	if !hided_grid:
		TweeningSystem.ui_tweener_handler(true,grid,Vector2(0,-600), 0,0)
		hided_grid = true
	if packet_queue.size() > 0:
		delay_timer += delta
		if delay_timer >= DELAY_BETWEEN_PACKETS:
			var data = packet_queue.pop_front() #send first packet
			_actual_send(data)
			delay_timer = 0.0

func _actual_send(data):
	var json_string = JSON.stringify(data)
	udp.put_packet(json_string.to_utf8_buffer())

func create_button():
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(128, 128)
	var btn = button_scene.instantiate()
	wrapper.add_child(btn)
	grid.add_child(wrapper)
func get_note_name(midi_number: int) -> String:
	var notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	# MIDI note 60 is C4. 
	var note_index = midi_number % 12
	return notes[note_index]

func handle_sound(note : int,on_off : bool):
	if on_off:
		if sound:
			var stream = stream_player.instantiate()
			stream.pitch_scale = pow(2.0, (note - 69.0) / 12.0)
			stream.name = str(note)
			var bend_semitones = ((slider.value - 8192.0) / 8192.0) * 2.0
			var bend_pitch_multiplier = pow(2.0, bend_semitones / 12)
			stream.base_pitch = stream.pitch_scale
			stream.pitch_scale = stream.base_pitch * bend_pitch_multiplier
			add_child(stream)
	else:
		if not sustain and sound: # stream player deletion, check if we do not have sustain.
			var stream = get_node(str(note))
			if stream:
				stream.name = "null"
				var tween = create_tween()
				tween.tween_property(stream,"volume_db",-80,3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(stream,"delete",true,0.1)

func _on_note_pressed(note):
	send_data( [0x90,  note, 127] )
	sequencer.handle_note(note,true)
	handle_sound(note,true)

func _on_note_released(note : int ):
	send_data([0x80, note, 0])
	sequencer.handle_note(note,false)
	handle_sound(note,false)

func play_note_animation(note : int):
	pass

func recieve_note(note : int, on_off : bool, channel : int):
	handle_sound(note,on_off)

func set_sustain(is_on: bool):
	var value = 127 if is_on else 0
	sustain = is_on
	# 0xB0 = Control Change on Channel 1
	# 64 = Sustain Pedal CC number
	send_data([0xB0, 64, value])


func _on_check_button_toggled(toggled_on: bool) -> void:
	set_sustain(toggled_on)


func _on_plus_pressed() -> void:
	octave += 1
	octave_number.text = str(octave)
	update_buttons_note()
func _on_minus_pressed() -> void:
	octave -= 1
	octave_number.text = str(octave)
	update_buttons_note()

func _on_scale_selector_item_selected(index: int) -> void:
	var all_scale_names = scales.keys()
	selected_scale = scales[all_scale_names[index]]
	update_buttons_note()
func update_buttons_note():
	var a : int = -1
	for i in range(total_buttons):
		var wrapper = grid.get_children()[i]
		var button = wrapper.get_children()[0]
		var button_t = button.get_children()[2]
		var note_in_array = selected_scale[i % selected_scale.size()]
		var octave_ = i / selected_scale.size() 
		var note = calculate_note(note_in_array,octave_)
		button.name = str(note)
		print(button_t.get_signal_list().size())
		
		for connections in button_t.pressed.get_connections():
			var callable = connections.callable
			if callable.get_method() == "_on_note_pressed":
				button_t.pressed.disconnect(callable) 
		
		for connections in button_t.released.get_connections():
			var callable = connections.callable
			if callable.get_method() == "_on_note_released":
				button_t.released.disconnect(callable) 
		
		button.get_node("Label").text = get_note_name(int(note))
		button_t.pressed.connect(_on_note_pressed.bind(note))
		button_t.released.connect(_on_note_released.bind(note))
		if a < 6:
			a += 1
		else:
			a = 0
		button.get_node("TouchScreenButton").texture_normal = button_icons[a]

func reload_buttons(_collumns: int, _rows : int):
	if total_buttons != 0:
		for child in grid.get_children():
			grid.remove_child(child) # Lo quita del grid YA
			child.queue_free()       # Lo borra de memoria después
	total_buttons = _collumns * _rows
	grid.columns = _collumns
	grid.add_theme_constant_override("v_separation", 25)
	grid.add_theme_constant_override("h_separation", 25)
	for i in range(total_buttons):
		create_button()
	update_buttons_note()


func calculate_note(note : int ,octave_ : int):
	return note + semitone + (12 * (octave_ + octave))





func _on_osc_ip_text_changed(new_text: String) -> void:
	ip_address = new_text
func _on_osc_port_text_changed(new_text: String) -> void:
	port = int(new_text)


func _on_button_pressed() -> void:
	udp.set_dest_address(ip_address, port)


func _on_plus_1_pressed() -> void:
	semitone += 1
	update_buttons_note()
	semitone_text.text = str(semitone)
func _on_minus_2_pressed() -> void:
	semitone -= 1
	update_buttons_note()
	semitone_text.text = str(semitone)


func _on_sound_toggled(toggled_on: bool) -> void:
	sound = toggled_on


func _on_colump_pressed() -> void:
	columns += 1
	columns_text.text = str(columns)
	reload_buttons(columns,rows)

func _on_columm_pressed() -> void:
	columns -= 1
	columns_text.text = str(columns)
	reload_buttons(columns,rows)


func _on_rowp_pressed() -> void:
	rows += 1
	rows_text.text = str(rows)
	reload_buttons(columns,rows)

func _on_rowm_pressed() -> void:
	rows -= 1
	rows_text.text = str(rows)
	reload_buttons(columns,rows)


func _on_hide_toggled(toggled_on: bool) -> void:
	if toggled_on:
		for i in get_children():
			if i.name != "hide" and i.name != "CenterContainer" and i is not AudioStreamPlayer :
				i.visible = false
	else:
		for i in get_children():
			if i is not AudioStreamPlayer:
				i.visible = true

var slider_tween : Tween
func _on_v_slider_drag_ended(_value_changed: bool) -> void:
	if !bend_latch:
		if slider_tween and slider_tween.is_valid():
			slider_tween.kill()
		slider_tween = create_tween()
		slider_tween.set_ease(Tween.EASE_IN_OUT)
		slider_tween.set_trans(Tween.TRANS_BACK)
		slider_tween.tween_property(slider,"value",8192.0,0.5)




func _on_pitch_bend_value_changed(value: float) -> void:
	# calculation of the separated 4 bits from the 14 bits
	var _value = int(value)
	var lsb = _value & 0x7F
	var msb = (_value >> 7) & 0x7F
	send_data([0xE0, lsb, msb])
	# emulation of the pitch bend:
	if sound:
		var bend_semitones = ((value - 8192.0) / 8192.0) * 2.0
		var bend_pitch_multiplier = pow(2.0, bend_semitones / 12)
		var nodes = get_children()
		for i in nodes:
			if i is AudioStreamPlayer:
				i.pitch_scale = i.base_pitch * bend_pitch_multiplier




func _on_check_box_toggled(toggled_on: bool) -> void:
	TweeningSystem.ui_tweener_handler(toggled_on,right,Vector2(-220,0), 0.3,0.2 ,0,false)


func _on_check_box_2_toggled(toggled_on: bool) -> void:
	TweeningSystem.ui_tweener_handler(toggled_on,left,Vector2(180,0), 0.3,0.2,0,false)

func _on_check_box_3_toggled(toggled_on: bool) -> void:
	TweeningSystem.ui_tweener_handler(toggled_on,top,Vector2(0,70), 0.3,0.2,0,false)


func _on_check_box_4_toggled(toggled_on: bool) -> void:
	TweeningSystem.ui_tweener_handler(toggled_on,color_picker,Vector2(0,-600), 0.8,0.2,toggled_on,false)
	TweeningSystem.ui_tweener_handler(toggled_on,grid,Vector2(0,-600), 0.8,0.1,0,!toggled_on)


func _on_color_picker_color_changed(color: Color) -> void:
	var style_box = ui_theme.get_stylebox("panel","Panel")
	if style_box is StyleBoxFlat:
		style_box.bg_color = color


func _on_button_toggled(toggled_on: bool) -> void:
	bend_latch = toggled_on
	_on_v_slider_drag_ended(0)


func _on_check_box_5_toggled(toggled_on: bool) -> void:
	TweeningSystem.ui_tweener_handler(toggled_on,graphs,Vector2(0,-120), 0.3,0.2 ,0,false)



func _on_check_box_6_toggled(toggled_on: bool) -> void:
	for node in settings_buttons.get_children():
		if node.name == "Key_settings" or node.name == "Connection" or node.name == "Colors":
			node.button_pressed = false
			node.disabled = toggled_on
	TweeningSystem.ui_tweener_handler(toggled_on,top2,Vector2(0,70), 0.3,0.2,0,false)



func _on_signature_1_plus_pressed() -> void:
	signature_1 += 1
	signature_text_1.text = str(signature_1)
	current_beat = 0


func _on_signature_1_minus_pressed() -> void:
	signature_1 -= 1
	signature_text_1.text = str(signature_1)
	current_beat = 0


func _on_signature_2_plus_pressed() -> void:
	signature_2 += 1
	signature_text_2.text = str(signature_2)


func _on_signature_2_minus_pressed() -> void:
	signature_2 -= 1
	signature_text_2.text = str(signature_2)


func _on_bpm_text_changed(new_text: String) -> void:
	var v_bpm = new_text.to_int()
	if v_bpm:
		bpm = v_bpm
	


func _on_metronome_toggled(toggled_on: bool) -> void:
	sequencer.set_metronome(toggled_on,bpm,signature_1,signature_2)



func _on_record_toggled(toggled_on: bool) -> void:
	if toggled_on:
		sequencer.start_recording()
	else:
		sequencer.finish_recording()


func _on_channel_plus_pressed() -> void:
	current_channel += 1
	channel_text_1.text = str(current_channel)

func _on_channel_minus_pressed() -> void:
	current_channel -= 1
	channel_text_1.text = str(current_channel)


func _on_play_toggled(toggled_on: bool) -> void:
	if toggled_on:
		sequencer.start_playback()
	else:
		sequencer.stop_playback()
