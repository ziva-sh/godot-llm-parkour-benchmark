class_name ParkourWorld
extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/parkour_player.gd")
const BOT_SCRIPT = preload("res://scripts/race_bot.gd")
const ASSET_ROOT = "res://Kenny_Platformer_Kit/Models/FBX format/"
const RACE_COLORS: Array[Color] = [Color("#ffb52e"), Color("#36d98b"), Color("#62a8ff")]

var races: Array[Dictionary] = []
var player: PLAYER_SCRIPT
var bots: Array[BOT_SCRIPT] = []
var active_race: int = -1
var player_checkpoint: int = 0
var elapsed_time: float = 0.0
var countdown: float = 0.0
var race_running: bool = false
var _banner_label: Label
var _timer_label: Label
var _status_label: Label
var _race_cards: Array[Label] = []
var _start_areas: Array[Area3D] = []
var _checkpoint_areas: Array[Area3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_setup_input_actions()
	_rng.seed = 481516
	_build_environment()
	_define_races()
	_build_hub()
	_build_courses()
	_build_player()
	_build_ui()

func _setup_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("restart_race", KEY_R)
	_add_key_action("pause_mouse", KEY_ESCAPE)

func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	if events.is_empty():
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, key_event)

func _process(delta: float) -> void:
	_animate_start_markers(delta)
	if active_race < 0:
		return
	if countdown > 0.0:
		countdown -= delta
		_banner_label.visible = true
		_banner_label.text = str(maxi(1, int(ceil(countdown))))
		if countdown <= 0.0:
			_begin_running()
		return
	if race_running:
		elapsed_time += delta
		_timer_label.text = _format_time(elapsed_time)
		_update_standings()
		if Input.is_action_just_pressed("restart_race"):
			_start_race(active_race)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_race") and active_race >= 0 and not race_running:
		_start_race(active_race)

func _define_races() -> void:
	var meadow_route: Array[Vector3] = [
		Vector3(-18.0, 1.1, 0.0), Vector3(-29.0, 1.1, 0.0), Vector3(-38.0, 2.5, -3.0),
		Vector3(-47.0, 3.9, 3.0), Vector3(-56.0, 5.5, 0.0), Vector3(-66.0, 4.1, -3.0),
		Vector3(-77.0, 6.0, 1.0), Vector3(-89.0, 3.1, 0.0)
	]
	var canyon_route: Array[Vector3] = [
		Vector3(18.0, 1.1, 0.0), Vector3(29.0, 1.1, 0.0), Vector3(38.0, 2.2, 4.0),
		Vector3(47.0, 3.5, -3.0), Vector3(56.0, 5.0, 4.0), Vector3(66.0, 6.5, -4.0),
		Vector3(76.0, 5.0, 3.0), Vector3(88.0, 7.0, 0.0)
	]
	var summit_route: Array[Vector3] = [
		Vector3(0.0, 1.1, -18.0), Vector3(0.0, 1.1, -29.0), Vector3(-5.0, 3.0, -38.0),
		Vector3(5.0, 5.0, -47.0), Vector3(-4.0, 7.2, -56.0), Vector3(4.0, 9.5, -65.0),
		Vector3(0.0, 12.0, -75.0), Vector3(0.0, 14.5, -87.0)
	]
	races = [
		{"name": "MEADOW DASH", "tagline": "Flowing jumps", "difficulty": "EASY", "route": meadow_route, "asset": "block-grass-large.fbx", "bot_times": [19.8, 21.5, 23.0]},
		{"name": "CANYON CIRCUIT", "tagline": "Precision gaps", "difficulty": "MEDIUM", "route": canyon_route, "asset": "block-grass-overhang-large.fbx", "bot_times": [23.5, 25.0, 27.0]},
		{"name": "FROST SUMMIT", "tagline": "Climb the sky", "difficulty": "HARD", "route": summit_route, "asset": "block-snow-large.fbx", "bot_times": [27.5, 29.0, 31.5]}
	]

func _build_environment() -> void:
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#5aa6d8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b8d8ed")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = false
	environment_node.environment = environment
	add_child(environment_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	var fog_plane: MeshInstance3D = MeshInstance3D.new()
	var fog_mesh: PlaneMesh = PlaneMesh.new()
	fog_mesh.size = Vector2(260.0, 260.0)
	fog_plane.mesh = fog_mesh
	fog_plane.position.y = -10.0
	fog_plane.material_override = _material(Color("#bce8f5"), 0.0)
	add_child(fog_plane)

func _build_hub() -> void:
	_add_platform(Vector3(0.0, -0.5, 0.0), Vector3(34.0, 1.0, 34.0), "block-grass-large.fbx")
	_add_platform(Vector3(0.0, -2.0, 0.0), Vector3(25.0, 3.0, 25.0), "block-grass-large-tall.fbx")
	_add_asset("flag.fbx", Vector3(-7.0, 0.0, 11.0), Vector3.ONE * 4.5)
	_add_asset("flag.fbx", Vector3(7.0, 0.0, 11.0), Vector3.ONE * 4.5, Vector3(0.0, PI, 0.0))
	for x: int in range(-14, 15, 4):
		_add_asset("fence-low-straight.fbx", Vector3(float(x), 0.0, 16.0), Vector3.ONE * 2.0)
	for i: int in range(16):
		var angle: float = TAU * float(i) / 16.0
		var radius: float = 22.0 + _rng.randf_range(0.0, 7.0)
		_add_asset("tree-pine.fbx", Vector3(cos(angle) * radius, -1.0, sin(angle) * radius), Vector3.ONE * _rng.randf_range(2.2, 3.7), Vector3(0.0, angle, 0.0))
	_add_asset("crate-strong.fbx", Vector3(-11.0, 0.0, 10.0), Vector3.ONE * 2.0)
	_add_asset("barrel.fbx", Vector3(11.0, 0.0, 10.0), Vector3.ONE * 2.0)

func _build_courses() -> void:
	for race_id: int in range(races.size()):
		var race: Dictionary = races[race_id]
		var route: Array[Vector3] = race["route"] as Array[Vector3]
		var asset_name: String = race["asset"] as String
		_build_start_gate(race_id, route[0])
		for point_index: int in range(route.size()):
			var point: Vector3 = route[point_index]
			var platform_size: Vector3 = _platform_size_for(race_id, point_index)
			_add_platform(Vector3(point.x, point.y - 0.6, point.z), platform_size, asset_name)
			if point_index > 0:
				_build_checkpoint(race_id, point_index, point, point_index == route.size() - 1)
			if point_index > 0 and point_index < route.size() - 1:
				_add_asset("arrow.fbx", point + Vector3(0.0, 1.0, 0.0), Vector3.ONE * 2.0, _rotation_toward(route[point_index + 1] - point))
		_build_course_decor(race_id, route)

func _platform_size_for(race_id: int, point_index: int) -> Vector3:
	if point_index == 0:
		return Vector3(8.0, 1.2, 8.0)
	if point_index == 7:
		return Vector3(9.0, 1.2, 8.0)
	if race_id == 0:
		return Vector3(6.5, 1.2, 6.5)
	if race_id == 1:
		return Vector3(5.2, 1.2, 5.2)
	return Vector3(5.8, 1.2, 5.8)

func _build_start_gate(race_id: int, position_value: Vector3) -> void:
	var color: Color = RACE_COLORS[race_id]
	_add_asset("flag.fbx", position_value + Vector3(-3.3, -1.0, 0.0), Vector3.ONE * 4.0)
	_add_asset("flag.fbx", position_value + Vector3(3.3, -1.0, 0.0), Vector3.ONE * 4.0, Vector3(0.0, PI, 0.0))
	_add_world_label(races[race_id]["name"] as String, position_value + Vector3(0.0, 3.7, 0.0), color, 52)
	_add_world_label("WALK IN TO START", position_value + Vector3(0.0, 2.8, 0.0), Color.WHITE, 26)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.18
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.position = position_value + Vector3(0.0, 0.12, 0.0)
	ring.material_override = _material(color, 2.5)
	ring.set_meta("base_y", ring.position.y)
	ring.set_meta("race_id", race_id)
	ring.add_to_group("start_marker")
	add_child(ring)
	var area: Area3D = Area3D.new()
	area.name = "RaceStart%d" % race_id
	area.position = position_value
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 6.5
	shape.height = 3.5
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_start_entered.bind(race_id))
	add_child(area)
	_start_areas.append(area)

func _build_checkpoint(race_id: int, index: int, position_value: Vector3, is_finish: bool) -> void:
	var area: Area3D = Area3D.new()
	area.name = "Race%dCheckpoint%d" % [race_id, index]
	area.position = position_value + Vector3(0.0, 1.2, 0.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(5.5, 3.5, 5.5)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_checkpoint_entered.bind(race_id, index, is_finish))
	add_child(area)
	_checkpoint_areas.append(area)
	if is_finish:
		_add_asset("flag.fbx", position_value + Vector3(-3.6, -1.0, 0.0), Vector3.ONE * 5.0)
		_add_asset("flag.fbx", position_value + Vector3(3.6, -1.0, 0.0), Vector3.ONE * 5.0, Vector3(0.0, PI, 0.0))
		_add_world_label("FINISH", position_value + Vector3(0.0, 4.5, 0.0), RACE_COLORS[race_id], 54)
	else:
		_add_asset("coin-gold.fbx", position_value + Vector3(0.0, 1.6, 0.0), Vector3.ONE * 1.8)

func _build_course_decor(race_id: int, route: Array[Vector3]) -> void:
	for i: int in range(1, route.size() - 1):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var offset: Vector3 = Vector3(0.0, -1.0, side * 4.3)
		if race_id == 2:
			_add_asset("tree-pine-snow-small.fbx", route[i] + offset, Vector3.ONE * 2.6)
		elif race_id == 1:
			_add_asset("rocks.fbx", route[i] + offset, Vector3.ONE * 2.2)
		else:
			_add_asset("flowers.fbx", route[i] + offset, Vector3.ONE * 2.4)
	if race_id == 1:
		_add_asset("trap-spikes-large.fbx", route[4] + Vector3(0.0, 0.65, -3.6), Vector3.ONE * 1.8)
	if race_id == 2:
		_add_asset("star.fbx", route[-1] + Vector3(0.0, 3.2, 0.0), Vector3.ONE * 2.8)

func _build_player() -> void:
	player = PLAYER_SCRIPT.new() as PLAYER_SCRIPT
	player.name = "Player"
	add_child(player)
	player.teleport_to(Vector3(0.0, 1.2, 8.0))
	player.fell.connect(_on_player_fell)

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.position = Vector2(24.0, 22.0)
	top_panel.size = Vector2(410.0, 92.0)
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color("#101b2dcc"), Color("#62a8ff")))
	canvas.add_child(top_panel)
	var top_box: VBoxContainer = VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 2)
	top_panel.add_child(top_box)
	var title: Label = Label.new()
	title.text = "  PARKOUR RIVALS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#ffffff"))
	top_box.add_child(title)
	_status_label = Label.new()
	_status_label.text = "  Explore the plaza • Enter any glowing start pad"
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color("#b9d5ed"))
	top_box.add_child(_status_label)

	_timer_label = Label.new()
	_timer_label.text = "00:00.000"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.position = Vector2(490.0, 24.0)
	_timer_label.size = Vector2(300.0, 64.0)
	_timer_label.add_theme_font_size_override("font_size", 38)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_label.add_theme_color_override("font_outline_color", Color("#102039"))
	_timer_label.add_theme_constant_override("outline_size", 9)
	canvas.add_child(_timer_label)

	var help: Label = Label.new()
	help.text = "WASD  MOVE    SPACE  JUMP    SHIFT  SPRINT    R  RESTART    ESC  MOUSE"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -54.0
	help.offset_bottom = -18.0
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_color_override("font_outline_color", Color("#102039"))
	help.add_theme_constant_override("outline_size", 6)
	canvas.add_child(help)

	var cards: VBoxContainer = VBoxContainer.new()
	cards.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cards.position = Vector2(-322.0, 22.0)
	cards.size = Vector2(298.0, 220.0)
	cards.add_theme_constant_override("separation", 8)
	canvas.add_child(cards)
	for race_id: int in range(races.size()):
		var card: Label = Label.new()
		card.text = "  %d  %s\n      %s • %s" % [race_id + 1, races[race_id]["name"], races[race_id]["tagline"], races[race_id]["difficulty"]]
		card.custom_minimum_size = Vector2(298.0, 64.0)
		card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_theme_font_size_override("font_size", 16)
		card.add_theme_color_override("font_color", Color.WHITE)
		card.add_theme_stylebox_override("normal", _panel_style(Color("#101b2dcc"), RACE_COLORS[race_id]))
		cards.add_child(card)
		_race_cards.append(card)

	_banner_label = Label.new()
	_banner_label.visible = false
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner_label.position = Vector2(-310.0, -100.0)
	_banner_label.size = Vector2(620.0, 200.0)
	_banner_label.add_theme_font_size_override("font_size", 74)
	_banner_label.add_theme_color_override("font_color", Color.WHITE)
	_banner_label.add_theme_color_override("font_outline_color", Color("#101b2d"))
	_banner_label.add_theme_constant_override("outline_size", 14)
	canvas.add_child(_banner_label)

func _start_race(race_id: int) -> void:
	active_race = race_id
	player_checkpoint = 0
	elapsed_time = 0.0
	countdown = 3.0
	race_running = false
	_timer_label.text = "00:00.000"
	player.controls_enabled = false
	var route: Array[Vector3] = races[race_id]["route"] as Array[Vector3]
	player.teleport_to(route[0] + Vector3(0.0, 0.2, 0.0))
	_clear_bots()
	_spawn_bots(race_id)
	_status_label.text = "  %s • Reach every checkpoint" % (races[race_id]["name"] as String)

func _begin_running() -> void:
	countdown = 0.0
	race_running = true
	player.controls_enabled = true
	_banner_label.text = "GO!"
	for bot: BOT_SCRIPT in bots:
		bot.start()
	var tween: Tween = create_tween()
	tween.tween_interval(0.55)
	tween.tween_callback(func() -> void: _banner_label.visible = false)

func _spawn_bots(race_id: int) -> void:
	var race: Dictionary = races[race_id]
	var route: Array[Vector3] = race["route"] as Array[Vector3]
	var bot_times: Array = race["bot_times"] as Array
	var bot_names: Array[String] = ["NOVA", "BOLT", "MINT"]
	var models: Array[String] = ["character-oobi.fbx", "character-oodi.fbx", "character-ooli.fbx"]
	for index: int in range(3):
		var bot: BOT_SCRIPT = BOT_SCRIPT.new() as BOT_SCRIPT
		bot.name = "Bot_%s" % bot_names[index]
		add_child(bot)
		var lane: Vector3 = Vector3(0.0, 0.0, float(index - 1) * 1.2)
		if race_id == 2:
			lane = Vector3(float(index - 1) * 1.1, 0.0, 0.0)
		bot.setup(bot_names[index], route, float(bot_times[index]), lane, ASSET_ROOT + models[index])
		bots.append(bot)

func _clear_bots() -> void:
	for bot: BOT_SCRIPT in bots:
		bot.queue_free()
	bots.clear()

func _finish_race() -> void:
	race_running = false
	player.controls_enabled = true
	for bot: BOT_SCRIPT in bots:
		bot.stop()
	var placement: int = 1
	for bot: BOT_SCRIPT in bots:
		if bot.progress() >= 1.0:
			placement += 1
	var suffix: String = "ST"
	if placement == 2:
		suffix = "ND"
	elif placement == 3:
		suffix = "RD"
	elif placement > 3:
		suffix = "TH"
	_banner_label.visible = true
	_banner_label.text = "%d%s PLACE\n%s" % [placement, suffix, _format_time(elapsed_time)]
	_status_label.text = "  Finished! Explore another glowing start pad"
	var finished_race: int = active_race
	active_race = -1
	var tween: Tween = create_tween()
	tween.tween_interval(4.0)
	tween.tween_callback(func() -> void:
		_banner_label.visible = false
		_clear_bots()
		var route: Array[Vector3] = races[finished_race]["route"] as Array[Vector3]
		player.set_checkpoint(route[-1] + Vector3(0.0, 0.3, 0.0))
	)

func _update_standings() -> void:
	var route: Array[Vector3] = races[active_race]["route"] as Array[Vector3]
	var player_progress: float = float(player_checkpoint) / float(route.size() - 1)
	var ahead: int = 0
	for bot: BOT_SCRIPT in bots:
		if bot.progress() > player_progress:
			ahead += 1
	_status_label.text = "  %s • Position %d/4 • Checkpoint %d/%d" % [races[active_race]["name"], ahead + 1, player_checkpoint, route.size() - 1]

func _on_start_entered(body: Node3D, race_id: int) -> void:
	if body != player or active_race >= 0:
		return
	_start_race(race_id)

func _on_checkpoint_entered(body: Node3D, race_id: int, index: int, is_finish: bool) -> void:
	if body != player or active_race != race_id or not race_running:
		return
	if index != player_checkpoint + 1:
		return
	player_checkpoint = index
	var route: Array[Vector3] = races[race_id]["route"] as Array[Vector3]
	player.set_checkpoint(route[index] + Vector3(0.0, 0.35, 0.0))
	if is_finish:
		_finish_race()
	else:
		_banner_label.visible = true
		_banner_label.text = "CHECKPOINT %d" % index
		var tween: Tween = create_tween()
		tween.tween_interval(0.45)
		tween.tween_callback(func() -> void:
			if race_running:
				_banner_label.visible = false
		)

func _on_player_fell() -> void:
	if race_running:
		elapsed_time += 2.0
		_banner_label.visible = true
		_banner_label.text = "+2.0s FALL"
		var tween: Tween = create_tween()
		tween.tween_interval(0.7)
		tween.tween_callback(func() -> void: _banner_label.visible = false)

func _animate_start_markers(delta: float) -> void:
	for marker_node: Node in get_tree().get_nodes_in_group("start_marker"):
		var marker: MeshInstance3D = marker_node as MeshInstance3D
		marker.rotation.y += delta * 0.8
		var base_y: float = float(marker.get_meta("base_y"))
		marker.position.y = base_y + sin(Time.get_ticks_msec() * 0.002 + float(marker.get_meta("race_id"))) * 0.12

func _add_platform(position_value: Vector3, size: Vector3, asset_name: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var packed: PackedScene = load(ASSET_ROOT + asset_name) as PackedScene
	if packed != null:
		var visual: Node3D = packed.instantiate() as Node3D
		visual.position.y = -size.y * 0.5
		visual.scale = Vector3(size.x / 2.082, size.y, size.z / 2.082)
		body.add_child(visual)
	else:
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _material(Color("#63b65f"), 0.0)
		body.add_child(mesh_instance)
	add_child(body)
	return body

func _add_asset(asset_name: String, position_value: Vector3, scale_value: Vector3 = Vector3.ONE, rotation_value: Vector3 = Vector3.ZERO) -> Node3D:
	var packed: PackedScene = load(ASSET_ROOT + asset_name) as PackedScene
	if packed == null:
		return Node3D.new()
	var instance: Node3D = packed.instantiate() as Node3D
	instance.position = position_value
	instance.scale = scale_value
	instance.rotation = rotation_value
	add_child(instance)
	return instance

func _add_world_label(text_value: String, position_value: Vector3, color: Color, size: int) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = size
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color("#102039")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label

func _material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style

func _rotation_toward(direction: Vector3) -> Vector3:
	return Vector3(0.0, atan2(direction.x, direction.z), 0.0)

func _format_time(seconds: float) -> String:
	var minutes: int = floori(seconds / 60.0)
	var whole_seconds: int = int(seconds) % 60
	var milliseconds: int = int(seconds * 1000.0) % 1000
	return "%02d:%02d.%03d" % [minutes, whole_seconds, milliseconds]
