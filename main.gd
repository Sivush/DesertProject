extends Node3D
## Главный скрипт игры.
## Создаёт плитки на поле, обрабатывает клики мыши и следит за победой и проигрышем.
## Внешний вид плиток собирает tile_factory.gd, а поведение плитки (копание) описано в item.gd.

const TileFactory = preload("res://tile_factory.gd")  # фабрика плиток


# ---------- НАСТРОЙКИ ----------

const ITEM_COUNT = 15  # сколько плиток на уровне (должно делиться на 3 и на число типов)


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
		# Тип плитки идёт по кругу, поэтому каждого типа поровну (15 плиток / 5 типов = по 3)
		var type = i % TileFactory.type_count()
		# Сколько копаний нужно плитке: 1 или 2
		var digs = 1 + randi() % 2

		# Фабрика собирает готовую плитку, а мы ставим её в свою клетку со случайным сдвигом
		var item = TileFactory.create(type, digs)
		var cell = cells[i]
		item.place(cell.x + randf_range(-0.3, 0.3), cell.y + randf_range(-0.3, 0.3))
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
				if not item.is_dug_out():
					item.dig()  # плитка ещё в песке: копаем
				elif not shelf.is_full():
					shelf.add_item(item)  # плитка откопана: отправляем на полку
