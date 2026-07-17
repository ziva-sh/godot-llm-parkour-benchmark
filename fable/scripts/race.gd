class_name Race
extends Node3D

## Holds one race course: start pad, finish area, bot racers and their waypoint path.

const BotScript = preload("res://scripts/bot.gd")

@export var race_name: String = "Race"
@export var bot_speeds: PackedFloat32Array = PackedFloat32Array()

@onready var start_area: Area3D = $StartArea
@onready var finish_area: Area3D = $FinishArea
@onready var start_marker: Marker3D = $StartMarker
@onready var return_marker: Marker3D = $ReturnMarker


func setup() -> void:
	var pts: Array = []
	for child: Node in $Waypoints.get_children():
		var m: Node3D = child
		pts.append(m.global_position)
	var i: int = 0
	for bot_node: Node in $Bots.get_children():
		var bot: RaceBot = bot_node
		if i < bot_speeds.size():
			bot.speed = bot_speeds[i]
		bot.setup(pts)
		i += 1


func start_bots() -> void:
	for bot_node: Node in $Bots.get_children():
		var bot: RaceBot = bot_node
		bot.start_race()


func reset_bots() -> void:
	for bot_node: Node in $Bots.get_children():
		var bot: RaceBot = bot_node
		bot.reset_to_start()


func standings(player_time: float) -> Array:
	var rows: Array = [{"name": "You", "time": player_time, "is_player": true}]
	for bot_node: Node in $Bots.get_children():
		var bot: RaceBot = bot_node
		rows.append({"name": bot.bot_name, "time": bot.projected_time(), "is_player": false})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	return rows
