extends Node3D
## Главный скрипт игры.
## Создаёт плитки на поле, обрабатывает клики мыши и следит за победой и проигрышем.


# ---------- НАСТРОЙКИ (числа можно менять здесь) ----------

const ITEM_SCENE = preload("res://Item.tscn")  # шаблон одной плитки (сцена Item.tscn)
const ITEM_COUNT = 15  # сколько плиток на уровне (должно делиться на 3 и на число типов)
const COLORS = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.PURPLE]  # цвет каждого типа
const SEGMENTS = [3, 4, 5, 6, 8]  # число углов у формы каждого типа (3 = треугольник, 4 = ромб...)

# Копание. Индекс в списках = сколько копаний осталось у плитки (0, 1 или 2).
const DIG_HEIGHTS = [0.33, 0.28, 0.24]  # высота плитки: чем глубже, тем ниже в песке
const DIG_TILTS = [0, 10, 15]  # наклон плитки в градусах: чем глубже, тем больше наклон
const COVER_ALPHA = [0.0, 0.5, 0.85]  # плотность пыли сверху: 0 = пыли нет, 1 = полностью закрыто

# Стрелка-указатель на плитке
const ARROW_TEXTURE = preload("res://items/arrow_white.png")  # картинка стрелки
const ARROW_SIZES = [0.7, 0.85, 0.95, 1.05, 1.15]  # размер стрелки для каждого типа (по форме плитки)


# ---------- ССЫЛКИ НА УЗЛЫ СЦЕНЫ ----------

@onready var shelf = $Shelf  # полка, на которую летят плитки (скрипт shelf.gd)
@onready var result_label = $UI/ResultLabel  # надпись «Победа!» / «Вы проиграли»


# ---------- СОСТОЯНИЕ ИГРЫ ----------

var items_left = ITEM_COUNT  # сколько плиток ещё не собрано
var game_over = false  # true, когда игра закончилась (победа или проигрыш)


# ---------- СТАРТ УРОВНЯ ----------

func _ready():
	# Подписываемся на сигналы полки: когда она заполнилась и когда собралась тройка
	shelf.shelf_full.connect(_on_shelf_full)
	shelf.triple_removed.connect(_on_triple_removed)

	# Делим поле на сетку 4x4 и перемешиваем клетки, чтобы плитки не лежали друг на друге
	var cells = []
	for gx in 4:
		for gz in 4:
			cells.append(Vector2(-3 + gx * 2, -3 + gz * 2))
	cells.shuffle()

	# Создаём плитки одну за другой
	for i in ITEM_COUNT:
		var item = ITEM_SCENE.instantiate()

		# Тип плитки (0..4): определяет цвет, форму и размер стрелки. Типы идут по кругу,
		# поэтому каждого типа ровно по 3 штуки (15 плиток / 5 типов)
		var type = i % COLORS.size()
		item.set_meta("type", type)

		# Красим плитку и задаём ей форму
		var material = StandardMaterial3D.new()
		material.albedo_color = COLORS[type]
		item.get_node("MeshInstance3D").material_override = material
		item.get_node("MeshInstance3D").mesh = make_shape(type)

		# Сколько копаний нужно плитке (1 или 2). Запоминаем в метаданных плитки
		var digs = 1 + randi() % 2
		item.set_meta("digs", digs)

		# Плитка лежит неподвижно (без физики), пока её не отправят на полку
		item.freeze = true

		# Ставим плитку в свою клетку со случайным сдвигом, глубиной и поворотом
		var cell = cells[i]
		item.position = Vector3(cell.x + randf_range(-0.3, 0.3), DIG_HEIGHTS[digs], cell.y + randf_range(-0.3, 0.3))
		item.rotation_degrees = Vector3(0, randf_range(0, 360), DIG_TILTS[digs])

		# Стрелка: плоская картинка чуть выше плитки
		var arrow = MeshInstance3D.new()
		arrow.name = "Arrow"  # имя нужно, чтобы найти её потом (shelf.gd уменьшает её на полке)
		arrow.mesh = make_arrow(type)
		arrow.position = Vector3(0, 0.09, 0)
		item.add_child(arrow)

		# Пыль: полупрозрачное пятно ещё выше стрелки, оно закрывает плитку и стрелку
		var cover = MeshInstance3D.new()
		cover.name = "Cover"  # имя нужно, чтобы найти пыль при копании (функция dig)
		cover.mesh = make_cover(COVER_ALPHA[digs])
		cover.position = Vector3(0, 0.12, 0)
		item.add_child(cover)

		add_child(item)


# ---------- ПОБЕДА И ПРОИГРЫШ ----------

# Полка убрала тройку одинаковых плиток
func _on_triple_removed():
	items_left -= 3
	if items_left <= 0:
		end_game("Победа!")

# Полка заполнилась, а тройки не собрались
func _on_shelf_full():
	end_game("Вы проиграли")

# Заканчиваем игру и показываем надпись
func end_game(text):
	game_over = true
	result_label.text = text + "\nНажми, чтобы начать заново"
	result_label.show()


# ---------- КЛИКИ МЫШИ ----------

func _input(event):
	# Реагируем только на нажатие левой кнопки мыши
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Если игра закончилась, любой клик начинает её заново
		if game_over:
			get_tree().reload_current_scene()
			return

		# Пускаем луч от камеры через точку клика и смотрим, во что он попал
		var camera = $Camera3D
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 100
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		if result:
			var item = result.collider
			# Нас интересуют только плитки, которые ещё не на полке (и полка сейчас не занята анимацией)
			if item is RigidBody3D and not shelf.has_item(item) and not shelf.busy:
				if item.get_meta("digs") > 0:
					dig(item)  # плитка ещё в песке: копаем
				elif not shelf.is_full():
					shelf.add_item(item)  # плитка откопана: отправляем на полку


# ---------- КОПАНИЕ ----------

# Одно копание: плитка поднимается, выпрямляется, а пыль над ней редеет
func dig(item):
	# Облачко песчинок в месте плитки
	spawn_dust(Vector3(item.global_position.x, 0.3, item.global_position.z))

	# Уменьшаем счётчик копаний
	var digs = item.get_meta("digs") - 1
	item.set_meta("digs", digs)

	# Плавная анимация (0.25 секунды): все изменения идут одновременно
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(item, "position:y", DIG_HEIGHTS[digs], 0.25)  # плитка поднимается
	tween.tween_property(item, "rotation_degrees:z", DIG_TILTS[digs], 0.25)  # плитка выпрямляется
	var cover = item.get_node("Cover")
	tween.tween_property(cover.mesh.material, "albedo_color:a", COVER_ALPHA[digs], 0.25)  # пыль редеет


# ---------- ПОСТРОЕНИЕ ВНЕШНЕГО ВИДА ----------

# Форма плитки: очень тонкий цилиндр с малым числом граней.
# 3 грани = треугольник, 4 = ромб, 5 = пятиугольник и так далее
func make_shape(type):
	var mesh = CylinderMesh.new()
	mesh.height = 0.15
	mesh.top_radius = 0.6
	mesh.bottom_radius = 0.6
	mesh.radial_segments = SEGMENTS[type]
	return mesh


# Облачко пыли при копании: песчинки разлетаются вверх и падают
func spawn_dust(pos):
	var dust = CPUParticles3D.new()

	# Одна песчинка: крошечная светлая сфера без теней
	var mesh = SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("F5E3B3")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	dust.mesh = mesh

	# Поведение частиц
	dust.emitting = false  # пока выключено, чтобы сначала поставить на место
	dust.amount = 30  # сколько песчинок
	dust.lifetime = 0.7  # сколько секунд живёт каждая
	dust.one_shot = true  # один взрыв, а не непрерывный поток
	dust.explosiveness = 1.0  # все песчинки вылетают разом
	dust.direction = Vector3(0, 1, 0)  # летят вверх
	dust.spread = 60  # разброс в стороны (градусы)
	dust.initial_velocity_min = 1.5  # скорость вылета (от и до)
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0, -8, 0)  # падают вниз
	dust.scale_amount_min = 0.6  # случайный размер песчинок
	dust.scale_amount_max = 1.4

	# Ставим в нужное место и запускаем
	add_child(dust)
	dust.global_position = pos
	dust.emitting = true

	# Через секунду убираем узел, чтобы не копился мусор
	get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


# Слой пыли над плиткой: плоский квадрат с мягким круглым пятном (в центре плотно, к краям прозрачно).
# alpha: общая плотность пыли (0 = нет пыли, 1 = полностью закрыто)
func make_cover(alpha):
	# Градиент от цвета песка (центр) к прозрачному (край)
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.85, 0.71, 0.48, 1.0))
	gradient.set_color(1, Color(0.85, 0.71, 0.48, 0.0))

	# Из градиента делаем круглую картинку
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)

	# Материал: картинка с прозрачностью, без теней
	var material = StandardMaterial3D.new()
	material.albedo_texture = tex
	material.albedo_color = Color(1, 1, 1, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Плоский квадрат, лежащий горизонтально
	var mesh = QuadMesh.new()
	mesh.size = Vector2(2.2, 2.2)
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.material = material
	return mesh


# Стрелка на плитке: плоский квадрат с белой картинкой стрелки.
# Размер зависит от типа, чтобы стрелка помещалась на мелких плитках
func make_arrow(type):
	var material = StandardMaterial3D.new()
	material.albedo_texture = ARROW_TEXTURE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh = QuadMesh.new()
	mesh.size = Vector2(ARROW_SIZES[type], ARROW_SIZES[type])
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.material = material
	return mesh
