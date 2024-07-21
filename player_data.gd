extends Node
class_name PlayerData

var lobby_id:String = "" # Gets set/cleared by lobby.gd

func clear_lobby(_some_id:String = "dung-covered-peasant"):
	lobby_id = _some_id

func set_lobby(_lobby_id:String):
	lobby_id = _lobby_id
