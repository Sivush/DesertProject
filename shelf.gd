extends Node3D

signal shelf_full
signal triple_removed

const SLOT_COUNT = 7

var items = []
var busy = false

func is_full():
	return items.size() >= SLOT_COUNT

func has_item(item):
	return items.has(item)

func slot_position(index):
	var camera = get_viewport().get_camera_3d()
	var local_pos = Vector3((index - 3) * 0.55, -1.6, -3)
	return camera.global_transform * local_pos

func add_item(item):
	busy = true

	var insert_at = items.size()
	for i in items.size():
		if items[i].get_meta("type") == item.get_meta("type"):
			insert_at = i + 1
	items.insert(insert_at, item)

	item.freeze = true
	item.get_node("CollisionShape3D").set_deferred("disabled", true)

	arrange()
	await get_tree().create_timer(0.5).timeout
	remove_matches()
	busy = false

	if is_full():
		shelf_full.emit()

func arrange():
	for i in items.size():
		var item = items[i]
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(item, "global_position", slot_position(i), 0.4)
		tween.tween_property(item.get_node("MeshInstance3D"), "scale", Vector3(0.4, 0.4, 0.4), 0.4)

func remove_matches():
	var counts = {}
	for item in items:
		var type = item.get_meta("type")
		counts[type] = counts.get(type, 0) + 1

	for type in counts:
		if counts[type] >= 3:
			var removed = 0
			for item in items.duplicate():
				if item.get_meta("type") == type and removed < 3:
					items.erase(item)
					item.queue_free()
					removed += 1
			triple_removed.emit()

	arrange()
