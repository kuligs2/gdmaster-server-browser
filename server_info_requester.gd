extends Node
class_name	ServerInfoRequester

# ----------------
# Main consts and variables
# ----------------
var HEADER_BYTES = PackedByteArray([255,255,255,255]) # Needs to match ServerInfoListener
const PACKET_TIMEOUT = 5
var REFRESH_TIMEOUT = 3
const TERMINATOR = 10 # Needs to match ServerInfoListener
const HEADER_STRING = "getserverInfo" # Needs to match ServerInfoListener
const MEASUREMENT_CYCLES = 5 # How many times do you measure latency to average it out
var latency_values : Array
var peer := PacketPeerUDP.new()
var peer_is_connected:bool = false
var packet_timer: Timer
var refresh_timer: Timer
var requester_thread : Thread
@export var player_data: PlayerData
@export var server_ip:String
@export var server_port:int
signal server_info_updated # Connected to address_item.gd

var serverinfo_cvars = {
	"lobby_id": "dung-covered-peasant", # Important for filtering out game that you host yourself
	"lobby_name":"Placeholder_name",
	"game_ip":"Placeholder_ip",
	"game_port":0,
	"clients":0,
	"max_clients":0,
	"latency":-1,
	"is_joined":false # This is set here
} # Gets set by lobby on server_info_listener

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	peer = PacketPeerUDP.new()
	packet_timer= Timer.new()
	refresh_timer = Timer.new()
	add_child(packet_timer)
	packet_timer.wait_time = PACKET_TIMEOUT 
	packet_timer.timeout.connect(_on_packet_timer_timeout)
	add_child(refresh_timer)
	refresh_timer.wait_time = REFRESH_TIMEOUT
	refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func get_packet_loop():
	while peer_is_connected:
		if peer.get_available_packet_count() > 0:
			parse_reply(peer)
	pass
		
func parse_reply(reply_peer:PacketPeerUDP):
	var ut: float = Time.get_unix_time_from_system()
	var ms: float = ut * 1000
	var current_time_ms: int = int(ms)
	# Validate packet
	var packet = reply_peer.get_packet()
	if packet.size() < HEADER_BYTES.size():
		print("ServerInfoRequester Packet not valid: Too small or empty [%s]" % packet.size())
		call_deferred_thread_group("discard_peer",reply_peer)
		return
	if not (packet[0] == HEADER_BYTES[0] \
	and packet[1] == HEADER_BYTES[1] \
	and packet[2] == HEADER_BYTES[2] \
	and packet[3] == HEADER_BYTES[3] \
	and packet.size() > HEADER_BYTES.size() + HEADER_STRING.length()) \
	and packet[packet.size()-2] == TERMINATOR: # Different for Listener
		print("ServerInfoRequester Packet HEADERS not valid")
		call_deferred_thread_group("discard_peer",reply_peer)
		return
	var header_end = packet.find(TERMINATOR)
	var header_slice = packet.slice(HEADER_BYTES.size(),header_end)
	var header_str = header_slice.get_string_from_utf8()
	# Validate header string
	if not header_str == HEADER_STRING:
		print("ServerInfoRequester Packet header not valid")
		call_deferred_thread_group("discard_peer",reply_peer)		
		return
	var time_end = packet.find(TERMINATOR,header_end+1)
	var time_slice = packet.slice(header_end+1,time_end)
	var server_info_cvar_slice =  packet.slice(time_end+1,packet.size()-2)
	var server_info_cvar_len = packet.decode_u8(packet.size()-1)
	# Validate serverinfo
	if server_info_cvar_len != server_info_cvar_slice.size():
		print("ServerInfoRequester Serverinfo cvars are not valid.")
		call_deferred_thread_group("discard_peer",reply_peer)		
		return	
	var time_str = time_slice.get_string_from_utf8()
	var time_int = time_str.to_int()
	var server_info_cvars_str = server_info_cvar_slice.get_string_from_utf8()
	# Do whatever with the return data
	var latency = get_latency(time_int,current_time_ms)
	var return_cvars = JSON.parse_string(server_info_cvars_str)
	if return_cvars:
		serverinfo_cvars = return_cvars
	serverinfo_cvars.latency = latency
	serverinfo_cvars.game_ip = reply_peer.get_packet_ip()
	serverinfo_cvars.is_joined = is_joined(serverinfo_cvars.lobby_id)
	# Add to array and request all over again
	if latency_values.size() < MEASUREMENT_CYCLES:
		# Add latency value to array and send request again
		latency_values.append(latency)
		call_deferred_thread_group("send_request")
		return
	else:
		var avg = average(latency_values)
		latency_values.clear()
		serverinfo_cvars.latency = avg
		server_info_updated.emit.call_deferred(serverinfo_cvars)
		#call_deferred_thread_group("emit_signal","server_info_updated",serverinfo_cvars)	
	call_deferred_thread_group("discard_peer",reply_peer)	
	pass

func send_request():
	if peer_is_connected:
		peer_is_connected = false
	peer = PacketPeerUDP.new()
	var error = peer.connect_to_host(server_ip, server_port)
	if error != OK:
		print("ServerInfoRequester Error send_request: Could not connect: ", error_string(error))
		packet_timer.stop()
		refresh_timer.stop()
	else:
		var packet : PackedByteArray = build_packet()
		error = peer.put_packet(packet)
		if error != OK:
			print("ServerInfoRequester Error send_request: ", error_string(error) )
			discard_peer(peer)
		else:
			peer_is_connected = true
			packet_timer.stop()
			packet_timer.start()
			if requester_thread != null:
				if requester_thread.is_alive() or requester_thread.is_started():
					requester_thread.wait_to_finish()
			requester_thread = Thread.new()
			requester_thread.start(get_packet_loop,Thread.PRIORITY_HIGH)

func start_refresher():
	refresh_timer.start(REFRESH_TIMEOUT)

func stop_refresher():
	peer_is_connected = false
	peer.close()
	packet_timer.stop()
	refresh_timer.stop()
	serverinfo_cvars.latency = -1
	finish_requester_thread()
	pass
	
func _on_packet_timer_timeout() -> void:
	# Disconnect peer
	print("ServerInfoRequester Packet timed out. It took longer for packet to arrive than: %s" % PACKET_TIMEOUT )
	peer_is_connected = false
	peer.close()
	packet_timer.stop()
	refresh_timer.stop()
	serverinfo_cvars.latency = -1
	server_info_updated.emit.call_deferred(serverinfo_cvars)
	
	#call_deferred_thread_group("emit_signal","server_info_updated",serverinfo_cvars)
	call_deferred_thread_group("finish_requester_thread")
	pass # Replace with function body.

func _on_refresh_timer_timeout() -> void:
	# Send request
	if not peer_is_connected:
		send_request()
	pass # Replace with function body.
	
func discard_peer(peer_obj:PacketPeerUDP, send_request_bool=false):
	peer_is_connected = false
	peer_obj.close()
	packet_timer.stop()
	call_deferred_thread_group("finish_requester_thread")
	if send_request_bool:
		call_deferred_thread_group("send_request")

func finish_requester_thread():
	peer_is_connected = false
	if requester_thread != null and (requester_thread.is_alive() or requester_thread.is_started()):
		requester_thread.wait_to_finish()

# ----------------
# Helper functions
# ----------------
func average(numbers: Array) -> float:
	var sum :=0.0
	for n in numbers:
		sum +=n
	return sum / numbers.size()

func is_joined(lobby_id:String) -> bool:
	if lobby_id == player_data.lobby_id:
		return true
	else:
		return false

func get_latency(packet_time:int,current_time_ms:int = -1) -> int:
	# returns in miliseconds
	if not current_time_ms == -1:
		return current_time_ms - packet_time	
	var ut: float = Time.get_unix_time_from_system()
	var ms: float = ut * 1000
	var msi: int = int(ms)
	var diff = msi - packet_time
	return diff

func build_packet() -> PackedByteArray : 
	# Build the packet
	var packet: PackedByteArray
	var header_bytes: PackedByteArray = HEADER_STRING.to_utf8_buffer()	
	var ut: float = Time.get_unix_time_from_system()
	var ms: float = ut * 1000
	var msi: int = int(ms)
	var st = str(msi)
	var time_bytes = st.to_utf8_buffer()
	packet.append_array(HEADER_BYTES)
	packet.append_array(header_bytes)
	packet.append(TERMINATOR)
	packet.append_array(time_bytes)
	packet.append(TERMINATOR)
	return packet
