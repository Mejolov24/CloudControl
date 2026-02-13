extends Node
var httprequester : HTTPRequest
var release_name : String
var new_update : bool = false
var update_check_error : int = 0 # 0 = none, 1 = connection error # 2 = parsing error, 3 unknown error
var raw_update_check_error : int = 0 # 3 = cant connect
var version_string : String = ""
var version_int : int = 0
const Current_Version = 1100000 # first digit ; 1 = alpha, 2 Beta, 3 release, Then we use 2 digits to represent bigger versions, like V1.0.15
const Github_Page = "https://github.com/Mejolov24/CloudControl/releases"
@export var root : Control
@export var label : Label
@export var grid : Control
func _ready() -> void:
	httprequester = HTTPRequest.new()
	add_child(httprequester)
	httprequester.request_completed.connect(_request_completed)
	httprequester.request("https://api.github.com/repos/Mejolov24/CloudControl/releases/latest")
func _request_completed(result, response_code, headers, body):
	if result == 0:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			release_name =  json["name"]
			var release_type = release_name[0]
			match release_type:
				"A":
					version_int = 1000000
				"B":
					version_int = 2000000
				"R":
					version_int = 3000000
				_:
					update_check_error = 2
			if release_name.contains("V"):
				version_string = release_name.get_slice("V", 1)
				if version_string:
					var parts : PackedStringArray = version_string.split(".",false)
					if parts.size() >= 3:
						var major : int = int(parts[0])
						var minor : int = int(parts[1])
						var patch : int = int(parts[2])
						version_int += (major * 100000 + (minor * 10000) + (patch * 100) )
					else : update_check_error = 2 
				else : update_check_error = 2
	elif result == 3:
		update_check_error = 1
	raw_update_check_error = result
	send_update_message()
	print("raw version : " + str(release_name))
	print("raw version int : " + str(version_int))
	print("error code : " + str(update_check_error))
	print("raw error : " + str(raw_update_check_error))
func send_update_message():
	var message : String = "Update detected! " + release_name + " Would you like to download it?"
	match update_check_error:
		1 :
			message = "No internet, couldnt check for updates"
		2 :
			message = "Error parsing update, maybe there is an update"
		3 :
			message = "Error cheking update, error code : " + str(raw_update_check_error)
	if update_check_error > 1 or update_check_error == 0:
		if version_int > Current_Version:
			new_update = true
	if new_update:
		var v_position = (get_viewport().get_visible_rect().size.y + 248) / 2
		TweeningSystem.ui_tweener_handler(true,self,Vector2(0, -v_position),0.3)
	elif update_check_error > 1:
		var v_position = (get_viewport().get_visible_rect().size.y + 248) / 2
		TweeningSystem.ui_tweener_handler(true,self,Vector2(0, -v_position),0.3)
	else:
		message = "No updates detected."
		TweeningSystem.ui_tweener_handler(false,grid,Vector2(0,-600), 0.5,0.1,0,true)
	print(message)
	label.text = message


func _on_update_pressed() -> void:
	OS.shell_open(Github_Page)
	TweeningSystem.ui_tweener_handler(false,grid,Vector2(0,-600), 0.5,0.1,0,true)
	TweeningSystem.ui_tweener_handler(false,self,Vector2(0, 0),0.3)
func _on_cancel_pressed() -> void:
	TweeningSystem.ui_tweener_handler(false,grid,Vector2(0,-600), 0.5,0.1,0,true)
	TweeningSystem.ui_tweener_handler(false,self,Vector2(0, 0),0.3)
