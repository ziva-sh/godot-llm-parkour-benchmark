class_name Game
extends Node3D

enum State { FREE, COUNTDOWN, RACING, RESULTS }

const HUB_SPAWN = Vector3(0.0, 1.2, 2.0)
const KILL_Y = -6.0

var state: State = State.FREE
var active_race: Race = null
var race_time: float = 0.0

@onready var player: Player = $Player
@onready var timer_label: Label = $HUD/TimerLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var info_label: Label = $HUD/InfoLabel


func _ready() -> void:
	for race_node: Node in get_tree().get_nodes_in_group("race"):
		var race: Race = race_node
		race.setup()
		race.start_area.body_entered.connect(_on_start_area_entered.bind(race))
		race.finish_area.body_entered.connect(_on_finish_area_entered.bind(race))
	timer_label.text = ""
	message_label.text = ""
	info_label.text = "WASD move  |  Space jump  |  Mouse look  |  Walk onto a race flag pad to start"


func _process(delta: float) -> void:
	if state == State.RACING and active_race != null:
		race_time += delta
		timer_label.text = "%s   %s" % [active_race.race_name, _fmt_time(race_time)]


func _physics_process(_delta: float) -> void:
	if player.global_position.y < KILL_Y:
		if state == State.RACING and active_race != null:
			player.respawn(active_race.start_marker.global_position + Vector3.UP * 0.4, active_race.start_marker.rotation.y)
		elif state == State.FREE:
			player.respawn(HUB_SPAWN, 0.0)


func _on_start_area_entered(body: Node3D, race: Race) -> void:
	if body != player or state != State.FREE:
		return
	_begin_race(race)


func _begin_race(race: Race) -> void:
	state = State.COUNTDOWN
	active_race = race
	player.frozen = true
	player.respawn(race.start_marker.global_position + Vector3.UP * 0.4, race.start_marker.rotation.y)
	race.reset_bots()
	timer_label.text = race.race_name
	for i: int in [3, 2, 1]:
		message_label.text = str(i)
		await get_tree().create_timer(0.8).timeout
	message_label.text = "GO!"
	player.frozen = false
	race_time = 0.0
	state = State.RACING
	race.start_bots()
	await get_tree().create_timer(1.0).timeout
	if state == State.RACING and message_label.text == "GO!":
		message_label.text = ""


func _on_finish_area_entered(body: Node3D, race: Race) -> void:
	if body != player or state != State.RACING or race != active_race:
		return
	state = State.RESULTS
	var player_time: float = race_time
	timer_label.text = "%s   %s" % [race.race_name, _fmt_time(player_time)]
	var rows: Array = race.standings(player_time)
	var place: int = 0
	var lines: Array = []
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		if row["is_player"]:
			place = i + 1
		var marker: String = "> " if row["is_player"] else "   "
		lines.append("%s%d. %s  -  %s" % [marker, i + 1, row["name"], _fmt_time(row["time"])])
	var headline: String = ["FIRST PLACE!", "2nd place", "3rd place"][mini(place - 1, 2)]
	message_label.text = "FINISH!  %s\n\n%s" % [headline, "\n".join(lines)]
	await get_tree().create_timer(5.0).timeout
	message_label.text = ""
	timer_label.text = ""
	race.reset_bots()
	player.respawn(race.return_marker.global_position, race.return_marker.rotation.y)
	active_race = null
	state = State.FREE


func _fmt_time(t: float) -> String:
	var minutes: int = int(t / 60.0)
	var seconds: float = t - minutes * 60
	return "%d:%05.2f" % [minutes, seconds]
