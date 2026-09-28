class_name AABBi
## AABB con coordenadas enteras (Vector3i). Portado del addon SimpleDungeons:
## se usa para detectar solapes entre habitaciones y para "empujarlas" dentro
## de los límites del dungeon durante la etapa de separación.

var position: Vector3i
var size: Vector3i
var end: Vector3i:
	get: return position + size

func _init(p_position: Vector3i = Vector3i.ZERO, p_size: Vector3i = Vector3i.ZERO) -> void:
	position = p_position
	size = p_size

## True si el punto está dentro de la caja (el borde final es exclusivo).
func contains_point(point: Vector3i) -> bool:
	return (
		point.x >= position.x and point.x < position.x + size.x and
		point.y >= position.y and point.y < position.y + size.y and
		point.z >= position.z and point.z < position.z + size.z
	)

## True si esta caja se solapa con otra.
func intersects(other: AABBi) -> bool:
	var a := normalized()
	var b := other.normalized()
	if b.position.x >= a.end.x or a.position.x >= b.end.x:
		return false
	if b.position.y >= a.end.y or a.position.y >= b.end.y:
		return false
	if b.position.z >= a.end.z or a.position.z >= b.end.z:
		return false
	return true

## Devuelve una copia movida lo mínimo posible para quedar dentro de `bounds`.
## Si `ignore_y` es true, el eje Y no se toca (para no alterar el piso de una sala al separarla).
func push_within(bounds: AABBi, ignore_y: bool) -> AABBi:
	var b := bounds.normalized()
	var result := AABBi.new(position, size).normalized()
	result.position = result.position.clamp(b.position, b.end - result.size)
	if ignore_y:
		result.position.y = position.y
	return result

## Devuelve una copia expandida lo mínimo necesario para incluir `point`.
func expand_to_include(point: Vector3i) -> AABBi:
	var new_position := Vector3i(
		min(position.x, point.x),
		min(position.y, point.y),
		min(position.z, point.z)
	)
	var new_end := Vector3i(
		max(end.x, point.x + 1),
		max(end.y, point.y + 1),
		max(end.z, point.z + 1)
	)
	return AABBi.new(new_position, new_end - new_position)

func translated(offset: Vector3i) -> AABBi:
	return AABBi.new(position + offset, size)

## Devuelve una copia agrandada `amount` celdas hacia cada lado en X/Z (el eje Y no se toca).
func grow_xz(amount: int) -> AABBi:
	return AABBi.new(
		position - Vector3i(amount, 0, amount),
		size + Vector3i(amount * 2, 0, amount * 2)
	)

## Devuelve una copia con tamaño positivo (por si algún cálculo dejó `size` negativo).
func normalized() -> AABBi:
	var new_position := position
	var new_size := size
	if new_size.x < 0:
		new_position.x += new_size.x
		new_size.x = -new_size.x
	if new_size.y < 0:
		new_position.y += new_size.y
		new_size.y = -new_size.y
	if new_size.z < 0:
		new_position.z += new_size.z
		new_size.z = -new_size.z
	return AABBi.new(new_position, new_size)
