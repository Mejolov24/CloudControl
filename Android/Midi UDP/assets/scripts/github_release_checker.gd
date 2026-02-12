extends Node
var httprequester : HTTPRequest
var release_name : String
var new_update : bool = false
var update_check_error : int = 0 # 0 = none, 1 = connection error # 2 = parsing error, 3 unknown error
var raw_update_check_error : int = 0 # 3 = cant connect
var version_string : String = ""
var version_int : int = 0
const Current_Version = 10000000 # first digit ; 1 = alpha, 2 Beta, 3 release
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	httprequester = HTTPRequest.new()
	add_child(httprequester)
	httprequester.request("https://api.github.com/repos/Mejolov24/CloudControl/releases/latest")
	httprequester.request_completed.connect(_request_completed)

func _request_completed(result, response_code, headers, body):
	if result == 0:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			release_name =  json["name"]
			if release_name.contains("V"):
				version_string = release_name.get_slice("V", 1)
				if version_string:
					var parts : PackedStringArray = version_string.split(".",false)
					if parts.size() >= 3:
						var major : int = int(parts[0])
						var minor : int = int(parts[1])
						var patch : int = int(parts[2])
						version_int = (major * 10000000) + (minor * 100000) + (patch * 1000)
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
	var message : String = "No updates detected"
	match update_check_error:
		1 :
			message = "No internet, couldnt check for updates"
		2 :
			message = "Error parsing update, maybe there is an update"
		3 :
			message = "Error cheking update, error code : " + str(raw_update_check_error)
	if ! update_check_error:
		if version_int > Current_Version:
			new_update = true
			message = "Update detected! Vesion = " + release_name
	print(message)
