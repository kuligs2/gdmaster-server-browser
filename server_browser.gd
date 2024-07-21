extends Control
class_name ServerBrowser

# ----------------
# Visual references
# ----------------
@onready var address_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/AddressList
@onready var gdmaster_ip: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/GdmasterIP
@onready var gdmaster_port: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/GdmasterPort
@onready var getservers_string: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/GetserversString2
@onready var direct_game_ip: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/HBoxContainer/DirectGameIP
@onready var direct_game_port: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/HBoxContainer/DirectGamePort
@onready var button_get_serv: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/ButtonGetServ
@onready var button_refresh: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/ButtonRefresh
@onready var button_lobby: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/ButtonLobby
@onready var button_direct_join: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/HBoxContainer/ButtonDirectJoin

# ----------------
# Main references and variables
# ----------------
const ADDRESS_ITEM = preload("res://address_item.tscn")
@onready var gdmaster_client: GdmasterClient = $GdmasterClient
@export var lobby_node:Lobby
@export var player_data:PlayerData
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gdmaster_client.serverlist_updated.connect(_on_serverlist_updated)
	button_lobby.button_down.connect(_on_button_lobby_button_down)
	button_get_serv.button_down.connect(_on_button_get_serv_button_down)
	button_direct_join.button_down.connect(_on_button_direct_join_button_down)
	button_refresh.button_down.connect(_on_button_refresh_button_down)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
# ----------------
# Gdmaster functions
# ----------------
func configure_gdmaster_client(ip:String,port:int):
	# Set ip and port of gdmaster to connect to
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
	# Port is ommited
	
	if custom_properties_cvar and custom_properties_cvar.size() >0:
		for key in custom_properties_cvar:
			stringer += "\\" + str(key) + "\\" + str(custom_properties_cvar[key])
	
	gdmaster_client.inforesponse_cvars = stringer
	pass	
	
# ----------------
# Helper functions
# ----------------
func add_address_item(ip:String,port:int):
	var port_str = str(port)
	var new_item_hash = str(ip + ":" + port_str).hash()
	var new_item:AddressItem = ADDRESS_ITEM.instantiate()
	new_item.hash_int = new_item_hash
	new_item.server_ip = ip
	new_item.server_info_port = port
	new_item.join_server.connect(_on_join_server)
	new_item.player_data = player_data
	address_list.add_child(new_item)
	pass
func refresh_all_servers():
	if address_list.get_children().size() >0:
		for child:AddressItem in address_list.get_children():
			child.start_refresher()
# ----------------
# Signal funcs
# ----------------
func _on_serverlist_updated(server_list):
	print("Server_list updated! ", server_list)
	# Clear items
	for child:AddressItem in address_list.get_children():
		child.clear_address_item()
	for server in server_list:
		var ip = server.split(":")[0]
		var port = server.split(":")[1].to_int()
		add_address_item(ip,port)
	pass

func _on_join_server(_serverinfo_cvars, address_item):
	lobby_node.join_game(_serverinfo_cvars, address_item)
	pass

# ----------------
# Button actions
# ----------------
func _on_button_direct_join_button_down() -> void:
	var bogus_serverinfo_cvars = {
		"game_ip": direct_game_ip.text,
		"game_port": direct_game_port.text.to_int(),
	}
	lobby_node.join_game(bogus_serverinfo_cvars)
	pass # Replace with function body.
	
func _on_button_lobby_button_down() -> void:
	if lobby_node:
		lobby_node.show()
		hide()
	pass # Replace with function body.

func _on_button_get_serv_button_down() -> void:
	gd_ip_cvar = gdmaster_ip.text
	gd_port_cvar = gdmaster_port.text.to_int()
	configure_gdmaster_client(gd_ip_cvar,gd_port_cvar)
	var get_servers_msg = getservers_string.text
	if not get_servers_msg.is_empty() and not gd_ip_cvar.is_empty() and gd_port_cvar:
		gdmaster_client.send_getservers(get_servers_msg)
	pass # Replace with function body.
	
func _on_button_refresh_button_down() -> void:
	refresh_all_servers()
	pass # Replace with function body.
