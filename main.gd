extends Node3D

const ITEM_SCENE = preload("res://Item.tscn")
const ITEM_COUNT = 15
const COLORS = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.PURPLE]

@onready var shelf = $Shelf
@onready var result_label = $UI/ResultLabel

var items_left = ITEM_COUNT
var game_over = false

func _ready():
	shelf.shelf_full.connect(_on_shelf_full)
	shelf.triple_removed.connect(_on_triple_removed)

	for i in ITEM_COUNT:
		var item = ITEM_SCENE.instantiate()

		var type = i % COLORS.size()
		item.set_meta("type", type)

		var material = StandardMaterial3D.new()
		material.albedo_color = COLORS[type]
		item.get_node("MeshInstance3D").material_override = material

		item.position = Vector3(randf_range(-3, 3), 2 + i * 1.1, randf_range(-3, 3))
		add_child(item)

func _on_triple_removed():
	items_left -= 3
	if items_left <= 0:
		end_game("Победа!")

func _on_shelf_full():
	end_game("Вы проиграли")

func end_game(text):
	game_over = true
	result_label.text = text + "\nНажми, чтобы начать заново"
	result_label.show()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_over:
			get_tree().reload_current_scene()
			return

		var camera = $Camera3D
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 100
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		if result:
			var item = result.collider
			if item is RigidBody3D and not shelf.has_item(item) and not shelf.busy:
				if not shelf.is_full():
					shelf.add_item(item)
