## Фабрика плиток: собирает готовую плитку нужного типа (форма, цвет, стрелка, пыль).
## Скрипт ни к чему не прикрепляется: main.gd вызывает его функции напрямую.

const ITEM_SCENE = preload("res://Item.tscn")  # шаблон одной плитки (сцена Item.tscn)
const ItemScript = preload("res://item.gd")  # скрипт плитки (нужен, чтобы взять его настройки)


# ---------- НАСТРОЙКИ ВНЕШНЕГО ВИДА (числа можно менять здесь) ----------

const COLORS = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.PURPLE]  # цвет каждого типа
const SEGMENTS = [3, 4, 5, 6, 8]  # число углов у формы каждого типа (3 = треугольник, 4 = ромб...)
const ARROW_TEXTURE = preload("res://items/arrow_white.png")  # картинка стрелки
const ARROW_SIZES = [0.7, 0.85, 0.95, 1.05, 1.15]  # размер стрелки для каждого типа (по форме плитки)


# Сколько всего типов плиток
static func type_count():
	return COLORS.size()


# Создаёт готовую плитку.
# type: тип плитки (0..4), digs: сколько копаний ей нужно (1 или 2)
static func create(type, digs):
	var item = ITEM_SCENE.instantiate()
	item.setup(type, digs)

	# Красим плитку и задаём ей форму
	var mesh_node = item.get_node("MeshInstance3D")
	var material = StandardMaterial3D.new()
	material.albedo_color = COLORS[type]
	mesh_node.material_override = material
	mesh_node.mesh = make_shape(type)

	# Стрелка: плоская картинка чуть выше плитки
	var arrow = MeshInstance3D.new()
	arrow.name = "Arrow"  # имя нужно, чтобы найти её потом (полка уменьшает её)
	arrow.mesh = make_arrow(type)
	arrow.position = Vector3(0, 0.09, 0)
	item.add_child(arrow)

	# Пыль: полупрозрачное пятно ещё выше стрелки, оно закрывает плитку и стрелку
	var cover = MeshInstance3D.new()
	cover.name = "Cover"  # имя нужно, чтобы найти пыль при копании (item.gd)
	cover.mesh = make_cover(ItemScript.COVER_ALPHA[digs])
	cover.position = Vector3(0, 0.12, 0)
	item.add_child(cover)

	return item


# Форма плитки: очень тонкий цилиндр с малым числом граней.
# 3 грани = треугольник, 4 = ромб, 5 = пятиугольник и так далее
static func make_shape(type):
	var mesh = CylinderMesh.new()
	mesh.height = 0.15
	mesh.top_radius = 0.6
	mesh.bottom_radius = 0.6
	mesh.radial_segments = SEGMENTS[type]
	return mesh


# Слой пыли над плиткой: плоский квадрат с мягким круглым пятном (в центре плотно, к краям прозрачно).
# alpha: общая плотность пыли (0 = нет пыли, 1 = полностью закрыто)
static func make_cover(alpha):
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
static func make_arrow(type):
	var material = StandardMaterial3D.new()
	material.albedo_texture = ARROW_TEXTURE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh = QuadMesh.new()
	mesh.size = Vector2(ARROW_SIZES[type], ARROW_SIZES[type])
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.material = material
	return mesh
