extends Node
class_name ServerInfoListener

# ----------------
# Main consts and variables
# ----------------
var HEADER_BYTES = PackedByteArray([255,255,255,255]) # Needs to match ServerInfoRequester
const TERMINATOR = 10 # Needs to match ServerInfoRequester
const HEADER_STRING = "getserverInfo" # Needs to match ServerInfoRequester
var server : UDPServer
var server_is_listening:bool = false
@export var listen_port = 27900
var listener_thread : Thread

var serverinfo_cvars = {
	"lobby_id": "dung-covered-peasant", # Important for filtering out game that you host yourself
	"lobby_name":"Placeholder_name",
	"game_ip":"Placeholder_ip",
	"game_port":0,
	"clients":0,
	"max_clients":0,
	"latency":-1,
} # Gets set by lobby. You can add whatever game data you want here for server browser to display.

func _ready() -> void:
	server = UDPServer.new()
	pass

func _process(_delta):
	pass

func _exit_tree():
	if listener_thread != null and listener_thread.is_alive():
		listener_thread.wait_to_finish()

func poll_server():
	while server_is_listening:
		server.poll() # Important!
		if server.is_connection_available():
			var peer: PacketPeerUDP = server.take_connection()
			if peer.get_available_packet_count() > 0:
				parse_request(peer)

func parse_request(peer:PacketPeerUDP):
	var packet = peer.get_packet()
	# Validate packet
	if not (packet[0] == HEADER_BYTES[0] \
	and packet[1] == HEADER_BYTES[1] \
	and packet[2] == HEADER_BYTES[2] \
	and packet[3] == HEADER_BYTES[3] \
	and packet.size() > HEADER_BYTES.size() + HEADER_STRING.length()) \
	and packet[packet.size()-1] == TERMINATOR: # Different for Requester
		print("ServerInfoListenerPacket not valid")
		call_deferred("discard_peer",peer)		
		return
	var header_end = packet.find(TERMINATOR)
	var header_slice = packet.slice(HEADER_BYTES.size(),header_end)
	var header_str = header_slice.get_string_from_utf8()
	# Validate header string
	if not header_str == HEADER_STRING:
		print("ServerInfoListener Packet header not valid")
		discard_peer(peer)
		return
	send_reply(peer,packet)
	pass

func send_reply(peer:PacketPeerUDP, request_packet:PackedByteArray):
	var packet : PackedByteArray
	var serverinfo_cvars_bytes = JSON.stringify(serverinfo_cvars).to_utf8_buffer()
	packet.append_array(request_packet)
	packet.append_array(serverinfo_cvars_bytes)
	packet.append(TERMINATOR)
	packet.append(serverinfo_cvars_bytes.size())
	var error = peer.put_packet(packet)
	if error != OK:
		print("ServerInfoListener Error send_reply: ", error_string(error) )	
	discard_peer(peer)

func start_listener():
	print("ServerInfoListener is starting!")
	var error = server.listen(listen_port)
	if error != OK:
		print("ServerInfoListener Could not start: ", error_string(error))
		server_is_listening = false
	else:
		server_is_listening = true
		print("ServerInfoListener is listening!")
		if listener_thread != null:
			if listener_thread.is_alive() or listener_thread.is_started():
				listener_thread.wait_to_finish()
		listener_thread = Thread.new()
		listener_thread.start(poll_server,Thread.PRIORITY_HIGH)

func stop_listener():
	if not server_is_listening:
		return
	server_is_listening = false
	server.stop()
	finish_listener_thread()
	print("ServerInfoListener is stopped!")
	
func discard_peer(peer):
	peer.close()

func finish_listener_thread():
	if listener_thread != null and listener_thread.is_alive():
		listener_thread.wait_to_finish()
