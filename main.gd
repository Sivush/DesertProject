extends Node3D

const ITEM_SCENE = preload("res://Item.tscn")
const ITEM_COUNT = 15
const COLORS = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.PURPLE]
const DIG_HEIGHTS = [0.33, 0.28, 0.24]
const DIG_TILTS = [0, 10, 15]
const SEGMENTS = [3, 4, 5, 6, 8]

const COVER_ALPHA = [0.0, 0.5, 0.85]

@onready var shelf = $Shelf
@onready var result_label = $UI/ResultLabel

var items_left = ITEM_COUNT
var game_over = false

func _ready():
	shelf.shelf_full.connect(_on_shelf_full)
	shelf.triple_removed.connect(_on_triple_removed)

	var cells = []
	for gx in 4:
		for gz in 4:
			cells.append(Vector2(-3 + gx * 2, -3 + gz * 2))
	cells.shuffle()

	for i in ITEM_COUNT:
		var item = ITEM_SCENE.instantiate()

		var type = i % COLORS.size()
		item.set_meta("type", type)

		var material = StandardMaterial3D.new()
		material.albedo_color = COLORS[type]
		item.get_node("MeshInstance3D").material_override = material
		item.get_node("MeshInstance3D").mesh = make_shape(type)

		var digs = 1 + randi() % 2
		item.set_meta("digs", digs)
		item.freeze = true
		var cell = cells[i]
		item.position = Vector3(cell.x + randf_range(-0.3, 0.3), DIG_HEIGHTS[digs], cell.y + randf_range(-0.3, 0.3))
		item.rotation_degrees = Vector3(0, randf_range(0, 360), DIG_TILTS[digs]) 
		var cover = MeshInstance3D.new()
		cover.name = "Cover"
		cover.mesh = make_cover(COVER_ALPHA[digs])
		cover.position = Vector3(0, 0.12, 0)
		item.add_child(cover)
		
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
				if item.get_meta("digs") > 0:
					dig(item)
				elif not shelf.is_full():
					shelf.add_item(item)

func dig(item):
	spawn_dust(Vector3(item.global_position.x, 0.3, item.global_position.z))
	var digs = item.get_meta("digs") - 1
	item.set_meta("digs", digs)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(item, "position:y", DIG_HEIGHTS[digs], 0.25)
	tween.tween_property(item, "rotation_degrees:z", DIG_TILTS[digs], 0.25) 
	var cover = item.get_node("Cover")
	tween.tween_property(cover.mesh.material, "albedo_color:a", COVER_ALPHA[digs], 0.25)
	
func make_shape(type):
	var mesh = CylinderMesh.new()
	mesh.height = 0.15
	mesh.top_radius = 0.6
	mesh.bottom_radius = 0.6
	mesh.radial_segments = SEGMENTS[type]
	return mesh	


func spawn_dust(pos):
	var dust = CPUParticles3D.new()

	var mesh = SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("F5E3B3")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	dust.mesh = mesh

	dust.emitting = false
	dust.amount = 30
	dust.lifetime = 0.7
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 60
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0, -8, 0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4

	add_child(dust)
	dust.global_position = pos
	dust.emitting = true
	get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


func make_cover(alpha):
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.85, 0.71, 0.48, 1.0))
	gradient.set_color(1, Color(0.85, 0.71, 0.48, 0.0))

	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)

	var material = StandardMaterial3D.new()
	material.albedo_texture = tex
	material.albedo_color = Color(1, 1, 1, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh = QuadMesh.new()
	mesh.size = Vector2(2.2, 2.2)
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.material = material
	return mesh
