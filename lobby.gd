extends Control
class_name Lobby

# ----------------
# Visual references
# ----------------
@onready var gdmaster_ip: LineEdit = $HBoxContainer/GdmasterPanel/MarginContainer/VBoxContainer/GdmasterIP
@onready var gdmaster_port: LineEdit = $HBoxContainer/GdmasterPanel/MarginContainer/VBoxContainer/GdmasterPort
@onready var game_name: LineEdit = $HBoxContainer/GdmasterPanel/MarginContainer/VBoxContainer/GameName
@onready var game_protocol: LineEdit = $HBoxContainer/GdmasterPanel/MarginContainer/VBoxContainer/GameProtocol
@onready var max_players: LineEdit = $HBoxContainer/GdmasterPanel/MarginContainer/VBoxContainer/MaxPlayers
@onready var public_check_box: CheckBox = $HBoxContainer/GdmasterPanel/MarginContainer/VBoxContainer/PublicCheckBox
@onready var lobby_name: LineEdit = $HBoxContainer/GameInfoPanel/MarginContainer/VBoxContainer/LobbyName
@onready var player_name: LineEdit = $HBoxContainer/GameInfoPanel/MarginContainer/VBoxContainer/PlayerName
@onready var game_port: LineEdit = $HBoxContainer/GameInfoPanel/MarginContainer/VBoxContainer/GamePort
@onready var listenert_port: LineEdit = $HBoxContainer/GameInfoPanel/MarginContainer/VBoxContainer/ListenertPort
@onready var server_browser_button: Button = $HBoxContainer/GameInfoPanel/MarginContainer/VBoxContainer/ServerBrowserButton
@onready var player_list: VBoxContainer = $HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/PlayerList
@onready var lobby_id: Label = $HBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/LobbyId
@onready var disconnect_button: Button = $HBoxContainer/GameInfoPanel/MarginContainer/VBoxContainer/DisconnectButton
@onready var host_game_button: Button = $HBoxContainer/GameInfoPanel/MarginContainer/VBoxContainer/HostGameButton

# ----------------
# Main references and variables
# ----------------
@onready var server_info_listener: ServerInfoListener = $ServerInfoListener
@onready var gdmaster_client: GdmasterClient = $GdmasterClient
@export var server_browser_node:ServerBrowser # Needs to be referenced manually in the node inspector
@export var player_data:PlayerData # Needs to be referenced manually in the node inspector
const LOBBY_KEY_LENGTH = 24 # Length of lobby key id value that is generated
var players_cvar = {} # List of players
var player_info_cvar = {
	"name": "NoName",
	"id" : -1
	} # Current player data
var game_port_cvar = 27800 # Game port, where godot game is hosted on
# Gdmaster ip and port must be set beforehand
var gd_ip_cvar = "127.0.0.1" # Gdmaster ip
var gd_port_cvar = 27777 # Gdmaster port
# Info response cvars for Gdmaster
var game_name_cvar = "RoboFlex"
var game_protocol_cvar = "4522" # has to be integer number string
var clients_cvar = 0 # has to be integer
var sv_maxclients_cvar = 16 # has to be integer
var public_cvar = 1 # has to be integer - either 1 or 0. 1 = true, 0 = false
var custom_properties_cvar = {} # you can add custom properties here. key=value

var serverinfo_cvars = {
	"lobby_id": "dung-covered-peasant", # Important for filtering out game that you host yourself
	"lobby_name":"Placeholder_name",
	"game_ip":"Placeholder_ip", # Gets set by server_info_requester
	"game_port":0,
	"clients":0,
	"max_clients":0,
	"latency":-1,
} # Gets set for server_info_listener

var lobby_id_cvar = ""
var connection_timer: Timer
var CONNECTION_TIMEOUT = 1.5
var CONNECTION_RETRIES = 0
var CONNECTION_MAX_RETRIES = 3
var current_address_item:AddressItem
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_list.visible = false
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	player_info_cvar = {"name" : player_name.text}
	public_check_box.toggle_mode = true
	public_check_box.toggled.connect(_on_public_checkbox_toggled)
	set_cvars_from_line_edits()
	gd_ip_cvar = gdmaster_ip.text
	gd_port_cvar = gdmaster_port.text.to_int()
	configure_gdmaster_client(gd_ip_cvar,gd_port_cvar)
	connection_timer = Timer.new()
	connection_timer.wait_time=CONNECTION_TIMEOUT
	connection_timer.timeout.connect(_on_connetion_timer_timeout)
	add_child(connection_timer)
	server_browser_button.button_down.connect(_on_server_browser_button_button_down)
	disconnect_button.button_down.connect(_on_disconnect_button_button_down)
	host_game_button.button_down.connect(_on_host_game_button_button_down)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

# ----------------
# Gdmaster functions
# ----------------
func configure_gdmaster_client(ip:String,port:int):
	# Set ip and port of Gdmaster server instance to connect to
	gdmaster_client.server_ip = ip
	gdmaster_client.server_port = port
	
func set_inforesponce_cvars():
	# cvars string must contain:
	# gamename\value\protocol\value\clients\value\sv_maxclients\value\public\value
	# and you can add any other properties.
	var stringer = ""
	stringer += "gamename\\" + str(game_name_cvar) 
	stringer += "\\protocol\\" + str(game_protocol_cvar)
	stringer += "\\clients\\" + str(clients_cvar)
	stringer += "\\sv_maxclients\\" + str(sv_maxclients_cvar)
	stringer += "\\public\\" + str(public_cvar)
	stringer += "\\port\\" + str(server_info_listener.listen_port) # Remeber to specify here listener port
	if custom_properties_cvar and custom_properties_cvar.size() >0:
		for key in custom_properties_cvar:
			stringer += "\\" + str(key) + "\\" + str(custom_properties_cvar[key])
	gdmaster_client.inforesponse_cvars = stringer
	set_serverinfo_cvars()
	pass	

func set_serverinfo_cvars():
	# Add any information about the game
	var new_serverinfo_cvars = {
	"lobby_id": lobby_id_cvar, # Important for filtering out game that you host yourself
	"lobby_name":lobby_name.text,
	"game_ip":"Placeholder_ip", # Gets set by server_info_requester
	"game_port":game_port_cvar,
	"clients":clients_cvar,
	"max_clients":sv_maxclients_cvar,
	"latency":-1,
	}
	serverinfo_cvars = new_serverinfo_cvars
	server_info_listener.serverinfo_cvars = new_serverinfo_cvars

func send_heartbeat():
	if not is_multiplayer_peer_online():
		return
	if not multiplayer.is_server():
		return
	gd_ip_cvar = gdmaster_ip.text
	gd_port_cvar = gdmaster_port.text.to_int()
	configure_gdmaster_client(gd_ip_cvar,gd_port_cvar)
	if not gd_ip_cvar.is_empty() and gd_port_cvar:
		set_inforesponce_cvars()
		gdmaster_client.send_heartbeat()

# ----------------
# Helper functions
# ----------------
func is_multiplayer_peer_online() -> bool:
	# Check if current multiplayer is hosting a game or connected to a game
	if multiplayer != null:
		if multiplayer.multiplayer_peer != null:
			if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
				if multiplayer.multiplayer_peer.host:
					return true
	return false
	
func lobby_id_key() ->String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
	var arr = chars.to_utf8_buffer()
	var key_len = LOBBY_KEY_LENGTH
	var result_key = ""
	for i in range(key_len):
		var c = ''
		c = chars.length()-1 - randi_range(0 , chars.length()-1)
		result_key += String.chr(arr[c])
	return result_key
	
func add_player(player_item):
	if not player_list.visible:
		player_list.visible = true
	var new_player = Label.new()
	new_player.text = player_item.name + ":" + str(player_item.id)
	player_list.add_child(new_player)
	pass
	
func remove_player(player_item):
	for item in player_list.get_children():
		if item.text == player_item.name + ":" + str(player_item.id):
			player_list.remove_child(item)
			item.queue_free()
			break
	pass

func remove_all_players():
	for item in player_list.get_children():
		item.queue_free()
	clients_cvar =0
	pass
	
func remove_multiplayer_peer():
	remove_all_players()
	multiplayer.multiplayer_peer = null
	server_info_listener.stop_listener()
	gdmaster_client.stop_heartbeat_timer()

func set_cvars_from_line_edits():
	game_name_cvar = game_name.text
	game_protocol_cvar = game_protocol.text.to_int()
	sv_maxclients_cvar = max_players.text.to_int()
	public_cvar = int(public_check_box.button_pressed)
	custom_properties_cvar = {"smelly":"feet"}
	game_port_cvar = game_port.text.to_int()
	
# ----------------
# Multiplayer api / Join game - Create/host game
# ----------------
func join_game(_serverinfo_cvars, address_item:AddressItem=null):
	if multiplayer.multiplayer_peer == null or multiplayer.get_peers().size() == 0:
		if _serverinfo_cvars.game_ip.is_empty():
			_serverinfo_cvars.game_ip = "127.0.0.1"
		var peer = ENetMultiplayerPeer.new()
		var error = peer.create_client(_serverinfo_cvars.game_ip, _serverinfo_cvars.game_port)
		if error:
			print("Error: join_game ", error)
			return error
		multiplayer.multiplayer_peer = peer
		connection_timer.start()
		var peer_id = peer.get_unique_id()
		player_info_cvar = {"name" : player_name.text, "id" : peer_id}
		players_cvar[peer_id] = player_info_cvar
		current_address_item = address_item
		if current_address_item != null:
			address_item.button_join.text = "Joining.."
			address_item.button_join.disabled = true

func create_game(port, max_clients):
	lobby_id_cvar = lobby_id_key()
	set_cvars_from_line_edits()
	var peer = ENetMultiplayerPeer.new()
	# Due to Godots limitations, you cant have multiplyer game with 1/1 players. When creating
	# server, you specify max_peers - this is the number of additional connections to the host
	var real_max_clients =0 
	if max_clients-1 <= 1:
		real_max_clients = 1
	else:
		real_max_clients = max_clients-1
	sv_maxclients_cvar = real_max_clients+1
	max_players.text = str(sv_maxclients_cvar)
	var error = peer.create_server(port, real_max_clients)
	if error:
		print("Error: create_game ", error)
		return error
	multiplayer.multiplayer_peer = peer
	player_info_cvar = {"name" : player_name.text, "id" : peer.get_unique_id()}
	players_cvar[peer.get_unique_id()] = player_info_cvar
	add_player(player_info_cvar)
	player_data.set_lobby(lobby_id_cvar)
	lobby_id.text = lobby_id_cvar
	clients_cvar +=1
	print("Create game player: ", player_info_cvar)
	server_info_listener.listen_port = listenert_port.text.to_int()
	server_info_listener.start_listener()
	send_heartbeat()

# ----------------
# RPC stuff
# ----------------
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players_cvar[new_player_id] = new_player_info
	add_player(new_player_info)

@rpc("any_peer", "reliable")
func _set_lobby_on_peer(_lobby_id_cvar):
	player_data.set_lobby(_lobby_id_cvar)
	lobby_id.text = _lobby_id_cvar
	var peer_id = multiplayer.multiplayer_peer.get_unique_id()
	connection_timer.stop()
	add_player(players_cvar[peer_id])
	if current_address_item != null:
		current_address_item.stop_refresher()
		current_address_item.start_refresher()

# ----------------
# Peer/host signal funcs
# ----------------
# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
# This gets called on server and clients
func _on_peer_connected(id):
	print("Player connected: %s on %s" % [id,multiplayer.multiplayer_peer.get_unique_id()])
	_register_player.rpc_id(id, player_info_cvar)
	# Do stuff if youre a host
	if multiplayer.multiplayer_peer.get_unique_id() == 1:
		clients_cvar +=1
		send_heartbeat()
		_set_lobby_on_peer.rpc_id(id, lobby_id_cvar)

# This gets called on server and clients
func _on_peer_disconnected(id):
	remove_player(players_cvar[id])
	players_cvar.erase(id)
	# Do stuff if youre a host
	if multiplayer.multiplayer_peer.get_unique_id() == 1:
		clients_cvar -=1
		send_heartbeat()

# When peer connects to host, gets emmited on the peer side
# Called only from clients	
func _on_connected_to_server():
	var peer_id = multiplayer.get_unique_id()
	players_cvar[peer_id] = player_info_cvar
	disconnect_button.show()
	host_game_button.hide()

# Called only from clients	
func _on_connection_failed():
	multiplayer.multiplayer_peer = null
	server_info_listener.stop_listener()
	player_data.clear_lobby()
	lobby_id.text = player_data.lobby_id

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players_cvar.clear()
	clients_cvar =0
	server_info_listener.stop_listener()
	host_game_button.show()
	disconnect_button.hide()
	remove_all_players()
	player_data.clear_lobby()
	lobby_id.text = player_data.lobby_id

func _on_connetion_timer_timeout():
	var _peers = multiplayer.multiplayer_peer.host.get_peers()
	var _current_peer:ENetPacketPeer = _peers[0]
	var _current_state = _current_peer.get_state()
	CONNECTION_RETRIES +=1
	match _current_state:
		ENetPacketPeer.PeerState.STATE_CONNECTED:
			print("ConnectionTimer Timeout: %s %s" % ["STATE_CONNECTED", multiplayer.multiplayer_peer.get_unique_id()])
			connection_timer.stop()
			CONNECTION_RETRIES = 0
		ENetPacketPeer.PeerState.STATE_CONNECTING:
			if CONNECTION_RETRIES > CONNECTION_MAX_RETRIES:
				connection_timer.stop()
				CONNECTION_RETRIES = 0
				print("ConnectionTimer Timeout: Took too many retries (%s). Failed to connect" % CONNECTION_MAX_RETRIES)
				players_cvar = {}
				player_info_cvar = {
				"name": "NoName",
				"id" : -1
				}
				if current_address_item != null:
					current_address_item.stop_refresher()
					current_address_item.start_refresher()
				current_address_item = null
			else:
				print("ConnectionTimer Timeout: %s %s (%s)" % ["STATE_CONNECTING", multiplayer.multiplayer_peer.get_unique_id(), CONNECTION_RETRIES])
	pass
# ----------------
# Button actions
# ----------------
func _on_public_checkbox_toggled(_toggled):
	public_cvar = int(_toggled)
	send_heartbeat()
	pass
	
func _on_server_browser_button_button_down() -> void:
	if server_browser_node:
		server_browser_node.show()
		server_browser_node.refresh_all_servers()
		hide()
	pass # Replace with function body.

func _on_host_game_button_button_down() -> void:
	create_game(game_port.text.to_int(), max_players.text.to_int())
	disconnect_button.show()
	host_game_button.hide()
	pass # Replace with function body.

func _on_disconnect_button_button_down() -> void:
	remove_multiplayer_peer()
	disconnect_button.hide()
	host_game_button.show()
	player_data.clear_lobby()
	lobby_id.text = "none"
	pass # Replace with function body.
