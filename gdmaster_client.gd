extends Node
class_name GdmasterClient

# ----------------
# Main consts and variables
# ----------------
var HEADER_BYTES = PackedByteArray([255,255,255,255]) # Needs to match Gdmaster
var EOT_BYTES = PackedByteArray([92,69,79,84,0,0,0]) # Needs to match Gdmaster - EOT
var udp : PacketPeerUDP
var transmission_in_progress := false # Used to serve multiple responses from Gdmaster (MTU limit). 
# DO NOT SET MANUALLY
var server_ip_list = []
var server_ip = "" # Gdmaster ip
var server_port = 27777 # Gdmaster port
var inforesponse_cvars = "" # Gets set by lobby
signal serverlist_updated(server_list)
@export var HEARBEAT_REFRESH_TIMEOUT = 480.0 # By default Gdmaster server has set the TIME_TO_LIVE 
# value to 600s = 10min, so this value mus not exceed the Gdmaster server vlaue. Otherwise this 
# server will be removed frommaster list.
@export var GETSERVERS_TIMEOUT = 5
var hearbeat_refresh_timer: Timer
var getservers_timer: Timer
var gdmaster_thread :Thread
var udp_is_connected:bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	udp = PacketPeerUDP.new()
	hearbeat_refresh_timer = Timer.new()
	getservers_timer= Timer.new()
	add_child(hearbeat_refresh_timer)
	add_child(getservers_timer)
	hearbeat_refresh_timer.wait_time = HEARBEAT_REFRESH_TIMEOUT
	hearbeat_refresh_timer.timeout.connect(_on_hearbeat_refresh_timer_timeout)
	getservers_timer.wait_time = GETSERVERS_TIMEOUT
	getservers_timer.timeout.connect(_on_getservers_timer_timeout)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func get_packet_loop():
	while udp_is_connected:
		if udp.get_available_packet_count() > 0:
			var bytes = udp.get_packet()
			parse_dpmaster_reply(bytes)
		pass	

func _exit_tree():
	if not gdmaster_thread == null:
		if gdmaster_thread.is_alive() == false:
			gdmaster_thread.wait_to_finish()

func parse_dpmaster_reply(byte_array:PackedByteArray):
	var blen = byte_array.size()
	if blen >=5 and byte_array[0]==255 and byte_array[1]==255 and byte_array[2]==255 and byte_array[3]==255:
		var getinfo_string = byte_array.slice(4,11).get_string_from_utf8()
		match getinfo_string:
			"getinfo":
				var readable_String = byte_array.slice(4).get_string_from_utf8()
				var string_array = readable_String.split(" ")
				var challenge = string_array[1]
				send_infoResponse(challenge,inforesponse_cvars)
			"getserv":
				getservers_timer.stop.call_deferred()
				var endo:PackedByteArray = byte_array.slice(byte_array.size()-7,byte_array.size()) # last seven bytes
				var endo1 = []
				for j in endo:
					endo1.append(j)
				var arr1_hash = Array(EOT_BYTES).hash() # Current ending
				var arr2_hash = endo1.hash() # EOT ending
				var address_array = byte_array.slice(22)
				var empty_arr = []
				var i := 0
				var iteration_len = 7
				var end := address_array.size()
				while (i < end):
					var addres_slice = address_array.slice(i+1,i+iteration_len)
					#do stuff here
					if not get_ip_port(addres_slice) == null:
						empty_arr.append(get_ip_port(addres_slice))
					i += iteration_len
				if not transmission_in_progress:
					server_ip_list = empty_arr # Reset serverlist
					if arr1_hash != arr2_hash:
						# the list goes on
						transmission_in_progress = true
						getservers_timer.start.call_deferred()
				else:
					server_ip_list.append_array(empty_arr)
					if arr1_hash == arr2_hash: # Compare if its EOT then stop adding to list
						transmission_in_progress = false
						serverlist_updated.emit.call_deferred(server_ip_list)
						udp.close()
						udp_is_connected =false
				if arr1_hash == arr2_hash and udp.is_socket_connected():
					udp.close()
					udp_is_connected =false
				serverlist_updated.emit.call_deferred(server_ip_list)
				getservers_timer.stop.call_deferred()
			_:
				pass
		pass
	pass

func send_getservers(sent_string:String = ""):
	if udp_is_connected:
		udp_is_connected = false
	udp = PacketPeerUDP.new()
	var error = udp.connect_to_host(server_ip, server_port)
	if error != OK:
		print("GdmasterClient Error send_getservers: Could not connect: ", error_string(error))
		
		getservers_timer.stop()
	else:
		var packet : PackedByteArray
		packet.append_array(HEADER_BYTES)
		packet.append_array(sent_string.to_utf8_buffer())
		error = udp.put_packet(packet)
		if error != OK:
			print("GdmasterClient Error send_getservers: ", error_string(error) )
			discard_peer(udp)
		else:
			udp_is_connected = true
			getservers_timer.stop()
			getservers_timer.start()
			if gdmaster_thread != null:
				if gdmaster_thread.is_alive() or gdmaster_thread.is_started():
					gdmaster_thread.wait_to_finish()
			gdmaster_thread = Thread.new()
			gdmaster_thread.start(get_packet_loop,Thread.PRIORITY_HIGH)

func send_heartbeat(sent_string:String = "heartbeat DarkPlaces"):
	var packet_array : PackedByteArray
	packet_array.append_array(HEADER_BYTES)
	packet_array.append_array(sent_string.to_utf8_buffer())
	packet_array.append(10)
	var error = udp.connect_to_host(server_ip, server_port)
	if error != OK:
		print("GdmasterClient Error send_heartbeat: ", error_string(error) )
		stop_heartbeat_timer()
		udp_is_connected=false
	else:
		udp_is_connected = true
		if gdmaster_thread == null:
			gdmaster_thread = Thread.new()
			gdmaster_thread.start(get_packet_loop,Thread.PRIORITY_HIGH)
		else:
			if not gdmaster_thread.is_alive():
				gdmaster_thread = Thread.new()
				gdmaster_thread.start(get_packet_loop,Thread.PRIORITY_HIGH)	
		error = udp.put_packet(packet_array)
		if error != OK:
			print("GdmasterClient Error send_heartbeat, put_packet: ", error_string(error) )
			stop_heartbeat_timer()
		else:
			start_heartbeat_timer()
	pass

func send_infoResponse(challange:String, cvars:String):
	# cvars string must contain:
	# gamename\value\protocol\value\clients\value\sv_maxclients\value\public\value
	# and you can add any other properties.
	var packet_array : PackedByteArray
	packet_array.append_array(HEADER_BYTES)
	var sent_string = "infoResponse"
	packet_array.append_array(sent_string.to_utf8_buffer())
	packet_array.append(10)
	var slash = "\\" # single slash
	var complete_string = ""
	var clean_cvars = ""
	if cvars.begins_with(slash):
		clean_cvars = cvars.substr(1,-1)
	else:
		clean_cvars = cvars
	if clean_cvars.ends_with(slash):
		clean_cvars = clean_cvars.substr(0,clean_cvars.length()-1)
	else:
		clean_cvars = cvars
	complete_string += slash + clean_cvars + slash + "challenge" + slash + str(challange)	
	packet_array.append_array(complete_string.to_utf8_buffer())
	var error = udp.put_packet(packet_array)
	if error != OK:
		print("GdmasterClient Error send_infoResponse: ", error_string(error) )
		udp_is_connected=false
		call_deferred_thread_group("finish_gdmaster_thread")
	else:
		udp_is_connected=false
		udp.close()
		call_deferred_thread_group("finish_gdmaster_thread")
	pass
	
# ----------------
# Helper functions
# ----------------
func get_ip_port(ip_byte_array:PackedByteArray):
	# How to convert 2 bytes into an integer?
	# Short answer: Assuming unsigned bytes, multiply the first byte by 256 and add it to the second byte
	if ip_byte_array.size() == 6:
		if ip_byte_array[3] == 0 and ip_byte_array[4] == 0 and ip_byte_array[5] == 0: return null
		var ip: String = str(ip_byte_array[0]) + "." + \
		str(ip_byte_array[1]) + "." + \
		str(ip_byte_array[2]) + "." + \
		str(ip_byte_array[3]) + ":" + \
		str((ip_byte_array[4]*256) + ip_byte_array[5])
		return ip
	else:
		return null

# ----------------
# Signal funcs
# ----------------
func _on_hearbeat_refresh_timer_timeout():
	send_heartbeat()

func _on_getservers_timer_timeout() -> void:
	# Disconnect peer
	print("GdmasterClient Get servers Packet timed out. It took longer for packet to arrive than: %s" % GETSERVERS_TIMEOUT )
	udp_is_connected = false
	udp.close()
	getservers_timer.stop()
	server_ip_list = []
	serverlist_updated.emit.call_deferred(server_ip_list)
	call_deferred_thread_group("finish_gdmaster_thread")

func start_heartbeat_timer():
	if hearbeat_refresh_timer.is_stopped():
		hearbeat_refresh_timer.start()
	else:
		hearbeat_refresh_timer.stop()
		hearbeat_refresh_timer.start()

func stop_heartbeat_timer():
	if not hearbeat_refresh_timer.is_stopped():
		hearbeat_refresh_timer.stop()

func discard_peer(peer):
	peer.close()

func finish_gdmaster_thread():
	gdmaster_thread.wait_to_finish()
