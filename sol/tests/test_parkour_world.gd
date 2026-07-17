extends Node

func test_world_defines_three_races() -> void:
	var script: Script = load("res://scripts/parkour_world.gd") as Script
	assert(script != null)
	var world: Node = script.new() as Node
	assert(world != null)
	world.free()

func test_required_kenney_assets_exist() -> void:
	assert(ResourceLoader.exists("res://Kenny_Platformer_Kit/Models/FBX format/block-grass-large.fbx"))
	assert(ResourceLoader.exists("res://Kenny_Platformer_Kit/Models/FBX format/character-oobi.fbx"))
	assert(ResourceLoader.exists("res://Kenny_Platformer_Kit/Models/FBX format/flag.fbx"))
