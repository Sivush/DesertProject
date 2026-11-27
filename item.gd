extends RigidBody3D
## Одна плитка (осколок). Скрипт прикреплён к корневому узлу сцены Item.tscn.
## Плитка сама знает свой тип, сколько копаний ей осталось, и умеет копаться.

const Effects = preload("res://effects.gd")  # эффекты (пыль)


# ---------- НАСТРОЙКИ КОПАНИЯ ----------
# Индекс в списках = сколько копаний осталось у плитки (0, 1 или 2)

const DIG_HEIGHTS = [0.33, 0.28, 0.24]  # высота плитки: чем глубже, тем ниже в песке
const DIG_TILTS = [0, 10, 15]  # наклон плитки в градусах: чем глубже, тем больше наклон
const COVER_ALPHA = [0.0, 0.5, 0.85]  # плотность пыли сверху: 0 = пыли нет, 1 = полностью закрыто


# ---------- ДАННЫЕ ПЛИТКИ ----------

var type = 0  # тип плитки (0..4): определяет цвет, форму и размер стрелки
var digs = 0  # сколько копаний ещё осталось (0 = плитка откопана)


# Начальная настройка плитки. Вызывается фабрикой сразу после создания
func setup(new_type, new_digs):
	type = new_type
	digs = new_digs
	freeze = true  # плитка лежит неподвижно (без физики), пока её не отправят на полку


# Ставит плитку на поле в точку (x, z): высота и наклон зависят от глубины, поворот случайный
func place(x, z):
	position = Vector3(x, DIG_HEIGHTS[digs], z)
	rotation_degrees = Vector3(0, randf_range(0, 360), DIG_TILTS[digs])


# Плитка откопана и готова лететь на полку?
func is_dug_out():
	return digs <= 0


# Одно копание: плитка поднимается, выпрямляется, а пыль над ней редеет
func dig():
	# Облачко песчинок в месте плитки
	Effects.spawn_dust(get_parent(), Vector3(global_position.x, 0.3, global_position.z))

	# Уменьшаем счётчик копаний
	digs -= 1

	# Плавная анимация (0.25 секунды): все изменения идут одновременно
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", DIG_HEIGHTS[digs], 0.25)  # плитка поднимается
	tween.tween_property(self, "rotation_degrees:z", DIG_TILTS[digs], 0.25)  # плитка выпрямляется
	var cover = get_node("Cover")
	tween.tween_property(cover.mesh.material, "albedo_color:a", COVER_ALPHA[digs], 0.25)  # пыль редеет
