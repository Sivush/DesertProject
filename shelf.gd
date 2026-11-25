extends Node3D
## Полка: хранит собранные плитки, раскладывает их по слотам и убирает тройки одинаковых.


# ---------- СИГНАЛЫ (сообщения для main.gd) ----------

signal shelf_full  # полка заполнилась
signal triple_removed  # собралась и убралась тройка одинаковых плиток


# ---------- НАСТРОЙКИ ----------

const SLOT_COUNT = 7  # сколько слотов на полке
const SLOT_SPACING = 0.55  # расстояние между слотами
const SLOT_Y = -1.7  # высота слотов относительно камеры (минус = ниже центра экрана)
const SLOT_DEPTH = -5.0  # расстояние от камеры до полки (минус = вперёд от камеры)


# ---------- СОСТОЯНИЕ ----------

var items = []  # плитки на полке по порядку слева направо
var busy = false  # true, пока идёт анимация (в это время клики по плиткам игнорируются)


# ---------- ПРОСТЫЕ ПРОВЕРКИ ----------

# Полка полностью занята?
func is_full():
	return items.size() >= SLOT_COUNT

# Эта плитка уже на полке?
func has_item(item):
	return items.has(item)


# ---------- ПОЗИЦИЯ СЛОТА ----------

# Где в мире находится слот с номером index.
# Слоты привязаны к камере, поэтому полка всегда на одном месте экрана
func slot_position(index):
	var camera = get_viewport().get_camera_3d()
	var local_pos = Vector3((index - 3) * SLOT_SPACING, SLOT_Y, SLOT_DEPTH)
	return camera.global_transform * local_pos


# ---------- ДОБАВЛЕНИЕ ПЛИТКИ ----------

func add_item(item):
	busy = true

	# Ищем место: если на полке уже есть плитки такого же типа, ставим новую рядом с ними
	var insert_at = items.size()
	for i in items.size():
		if items[i].get_meta("type") == item.get_meta("type"):
			insert_at = i + 1
	items.insert(insert_at, item)

	# Отключаем физику и клики по плитке, пока она на полке
	item.freeze = true
	item.get_node("CollisionShape3D").set_deferred("disabled", true)

	# Раскладываем плитки по слотам и ждём окончания анимации
	arrange()
	await get_tree().create_timer(0.5).timeout

	# Убираем тройки, если они собрались
	remove_matches()
	busy = false

	# Если после этого полка всё ещё полная, игра проиграна
	if is_full():
		shelf_full.emit()


# ---------- РАСКЛАДКА ----------

# Плавно переносит все плитки в их слоты и уменьшает до размера слота
func arrange():
	for i in items.size():
		var item = items[i]
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(item, "global_position", slot_position(i), 0.4)  # летит в слот
		# Уменьшаем плитку и стрелку (они отдельные узлы, поэтому каждую отдельно)
		tween.tween_property(item.get_node("MeshInstance3D"), "scale", Vector3(0.4, 0.4, 0.4), 0.4)
		tween.tween_property(item.get_node("Arrow"), "scale", Vector3(0.4, 0.4, 0.4), 0.4)


# ---------- ТРОЙКИ ----------

# Убирает с полки любые три одинаковых плитки
func remove_matches():
	# Считаем, сколько плиток каждого типа лежит на полке
	var counts = {}
	for item in items:
		var type = item.get_meta("type")
		counts[type] = counts.get(type, 0) + 1

	# Если какого-то типа три или больше, удаляем три плитки этого типа
	for type in counts:
		if counts[type] >= 3:
			var removed = 0
			for item in items.duplicate():
				if item.get_meta("type") == type and removed < 3:
					items.erase(item)
					item.queue_free()
					removed += 1
			triple_removed.emit()  # сообщаем main.gd, что тройка собрана

	# Сдвигаем оставшиеся плитки, чтобы закрыть пустые места
	arrange()
