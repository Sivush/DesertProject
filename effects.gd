## Визуальные эффекты. Сюда будем добавлять новые (звуки, частицы сборки тройки и т.д.).
## Скрипт ни к чему не прикрепляется: другие скрипты вызывают его функции напрямую.


# Облачко пыли: песчинки разлетаются вверх и падают.
# parent: узел, в который добавится эффект (обычно главная сцена)
# pos: место в мире, где появится пыль
static func spawn_dust(parent, pos):
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
	parent.add_child(dust)
	dust.global_position = pos
	dust.emitting = true

	# Через секунду убираем узел, чтобы не копился мусор
	parent.get_tree().create_timer(1.0).timeout.connect(dust.queue_free)
