# Server browser for Godot games using Gdmaster (masterlist)

This is a conceptual work. Not tested in production.

## Description

This is a simple server browser example using Gdmaster - Open masterlist server written in Godot's 
gdscript. 

For reasons, hosting a game in godot requires atleast two ports:
	1) Game port - port where the godot game is hosted at using high level 	multiplayer API. This 
	port is used by multiplayer peers to connect to the hosted game;
	2) Listener port - port on which server information is served at. This port is used by clients 
	retrieving server information during the server browser refresh;

It is best practice to serve Gdmaster (masterlist) server your hosted game's listener port, so that 
this IP:PORT combo would be served back to clients, upon get servers request, from Gdmaster 
(masterlist).

## Where to start?

Everything starts from main.tscn scene which has lobby.tscn, server_browser.tscn and 
player_data.tscn nodes. PlayerData node holds information about current lobby, and is referenced in 
both Lobby and ServerBrowser nodes via exported variables. Both Lobby and ServerBrowser nodes have 
references to each other via exported variables. This is important. Without these references you 
wont be able to switch between these scenes during runtime.

Lobby node holds data about Gdmaster server, player and lobby/game. Here you define your game 
parameters for Gdmaster, lobby parameters. Onece you press "Host game" button, a "create_game()" 
function will create game and serve server information on listener port and will send game 
information to Gdmaster. Also check GdmasterClient node for more configuration. By default this will
work with default configuration of Gdmaster server. But Gdmaster client must match Gdmaster server 
configurations. See more info on Gdmaster server configuration [Gdmaster](https://github.com/kuligs2/gdmaster).

ServerBrowser node holds data about servers, retreived form Gdmaster (masterlist) server. Here you 
need to specify Gdmaster server information and information about the game you want to request from 
Gdmaster. By pressing button "Get servers" Gdmaster will server you a list of available games based 
on the requested game parameters. After that you can refresh listed server datas by pressing 
"Refresh servers".

## How everything works?

The main idea is this:
	- A game is created using Godots high level multiplayer API.
	- Server information listener is launched on a different port.
	- The game data is sent through GdmasterClient to Gdmaster (masterlist) server to hold the 
	hosted game info, IP and listener port (this is important).
	- A Godot multiplayer peer client makes a request server list request through GdmasterClient on 
	Gdmaster (masterlist) server for currently available servers with given game parameters.
	- A list of servers then is parsed by ServerBrowser node and for each server item, and 
	AddressItem is created.
	- Upon the creation of AddressItem, server info request is made to the IP:PORT (Listener port on 
	the hosted game machine).
	- Server information is served back at AddressItem.
	- AddressItem then displays current server information on the server browser.
	- Client/multiplayer peer then presses the "Join" button on the AddressItem	in ServerBrowser 
	node and is connected to the game.
	- A server info request by AddressItem is emmited, to get the updated information about the 
	server.
	- AddressItem "Join" button text is then updated to "In game".

Of course more things happen during all these steps. Main thing I didn't mention- the lobby_id is 
the main property that gets set in PlayerData node once a peer is connected to the hosted game. 
This lobby_id is used by the ServerInfoRequester in AddressItem to test with funtion "is_joined" if 
the peer is connected to this AddressItem so that the AddressItem "Join" button could be renamed 
appropriately.

## Limitations

Due to how high-level multiplayer works in Godot, there are number of hacks that you need to
implement in order to have fluid code progression.

One such area is in "peer.create_server()" function where you need to specify max number of peers
that are allowed to join the game. This number does not include the host, so in total there will be
max number of peers + host of player in the game. You can't have a game of 1/1 players. The minimum
player limit for multiplayer game is 2.

Another thing to consider is to manage the "peer.create_client()" timeouts. Once you create client,
it wont throw error if the client was refused by the server or something else. The multiplayer API
will still be valid object. So you have to run a timer to check and see currect "PeerState".

## Whats next?

This was my attempt to solve the good ol' question - Will it blen.. How to server browser in Godot? 
I think i did pretty well for a nobody, with somehelp from both Godotforums and Xonotic communities. 
Im sure there are better ways to do things. 
