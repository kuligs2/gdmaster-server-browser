extends HBoxContainer
class_name AddressItem

# ----------------
# Visual references
# ----------------
@onready var label_ip: Label = $LabelIP
@onready var label_lobby: Label = $LabelLobby
@onready var label_players: Label = $LabelPlayers
@onready var label_ping: Label = $LabelPing
@onready var button_join: Button = $ButtonJoin

# ----------------
# Main references and variables
# ----------------
@onready var server_info_requester: ServerInfoRequester = $ServerInfoRequester
@export var player_data:PlayerData # Gets set by server_browser.gd
signal join_server(serverinfo_cvars, address_item) # Connected to server_browser.gd
var server_ip:String # Gets set by server_browser.gd
var server_info_port:int # Gets set by server_browser.gd
var hash_int: int 

var serverinfo_cvars = {
	"lobby_id": "dung-covered-peasant", # Important for filtering out game that you host yourself
	"lobby_name":"Placeholder_name",
	"game_ip":"Placeholder_ip",
	"game_port":0,
	"clients":0,
	"max_clients":0,
	"latency":-1,
} # Gets set by lobby on server_info_listener

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	server_info_requester.server_info_updated.connect(_on_server_info_updated)
	server_info_requester.server_ip = server_ip
	server_info_requester.server_port = server_info_port
	server_info_requester.player_data = player_data
	button_join.button_down.connect(_on_button_join_down)
	start_refresher()
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func start_refresher():
	server_info_requester.send_request()
	#server_info_requester.start_refresher()
	
func stop_refresher():
	server_info_requester.stop_refresher()

func set_labels():
	label_ip.text = str(serverinfo_cvars.game_ip) + ":" + str(serverinfo_cvars.game_port)
	label_players.text = str(serverinfo_cvars.clients)+"/"+str(serverinfo_cvars.max_clients)
	label_ping.text = str(serverinfo_cvars.latency)
	label_lobby.text = str(serverinfo_cvars.lobby_name)
	if serverinfo_cvars.is_joined:
		button_join.disabled = true
		button_join.text = "In game"
	else:
		button_join.disabled = false
		button_join.text = "Join"
	pass

func clear_address_item():
	server_info_requester.stop_refresher()
	queue_free()
	
func _on_button_join_down():
	join_server.emit(serverinfo_cvars, self)
	
func _on_server_info_updated(serverinfo_response_cvars):
	serverinfo_cvars = serverinfo_response_cvars
	
	if serverinfo_cvars.latency == -1:
		queue_free()
		
	set_labels()
	if not visible:
		show()
	pass
