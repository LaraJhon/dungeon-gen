extends Node3D
class_name DungeonRoom
## Clase base para cualquier habitación prefabricada del dungeon.
## Convención (misma que usa el addon SimpleDungeons real, pero implementada
## acá como código plano, sin plugin ni dependencias externas):
##
##   - Puertas: nodos Node3D hijos nombrados con prefijo "DOOR" (obligatoria)
##     o "DOOR?" (opcional). La posición local del nodo define en qué celda
##     de la sala está la puerta (en qué piso, si la sala ocupa varios).
##   - Dirección: SIEMPRE la rotación Y del nodo (0/90/180/270), sea la sala
##     normal o de escalera. Una sala de escalera no tiene puertas "hacia
##     arriba/abajo": tiene una puerta normal (horizontal) en su piso de
##     abajo y otra puerta normal en su piso de arriba; lo único especial es
##     que adentro de la sala se puede subir y bajar libremente entre esos
##     pisos (así se conectan pisos consecutivos sin "atravesar el aire").
##     El sufijo "_UP"/"_DOWN" en el nombre es solo para que el autor de la
##     sala identifique cuál puerta es cuál; no afecta la lógica.

## Tamaño de la sala en voxels. Para una sala de escalera que conecta 2 pisos,
## el eje Y debe ser 2 (ocupa el piso de abajo Y el de arriba).
@export var size_in_voxels: Vector3i = Vector3i(3, 1, 3)

## Debe coincidir con el voxel_scale del DungeonGenerator.
@export var voxel_scale: Vector3 = Vector3(4, 4, 4)

## Marcá esto true si la sala tiene al menos una puerta "_UP" y una "_DOWN"
## (conecta 2 pisos consecutivos). El generador solo permite viajar entre
## pisos A TRAVÉS de una sala marcada así, nunca "atravesando el aire".
@export var is_stair_room: bool = false

## Qué tan seguido la elige el generador, relativo a las demás salas. Con
## peso 2 sale el doble de veces que una de peso 1; con 0 no sale nunca.
## (No afecta a las escaleras: esas se agregan solo cuando hacen falta.)
@export_range(0.0, 10.0, 0.1) var spawn_weight: float = 1.0

## Cuántas veces como máximo puede aparecer esta sala en un mismo dungeon.
## 0 = sin límite. Útil para salas grandes o "especiales" (ej: 1).
@export var max_per_dungeon: int = 0

## Marcalo si las aberturas de las puertas de esta sala son tan altas como el
## pasillo (sin pared encima), como en la escalera. Así el generador también
## abre la parte de arriba del pasillo hacia la sala. Dejalo apagado en salas
## con marco de puerta normal (Door_Frame): ahí arriba hay pared.
@export var tall_doors: bool = false

## Posición en la grilla del dungeon una vez colocada (la setea el generador).
var grid_position: Vector3i = Vector3i.ZERO

## Cuántos pasos de 90° rotó el generador esta instancia al colocarla (0-3).
var placement_rot_steps: int = 0

## Lista de puertas detectadas: cada entrada es un Dictionary
## { "node": Node3D, "local_cell": Vector3i, "direction": Vector3i, "optional": bool }
var doors: Array = []

func _ready() -> void:
	# Si el generador ya las detectó (antes de rotar la sala), NO se recalculan:
	# a esta altura size_in_voxels ya tiene el tamaño rotado y la cuenta daría
	# celdas equivocadas en cualquier sala rotada 90°/270°.
	if doors.is_empty():
		_collect_doors()

## Fuerza la detección de puertas sin esperar a que el nodo entre al árbol de
## escena (el generador la necesita ANTES de hacer add_child()).
func detect_doors() -> void:
	_collect_doors()

func _collect_doors() -> void:
	doors.clear()
	# Las puertas ya no tienen por qué ser hijas directas de la sala: con la
	# técnica de "caja de resta" (un CSGBox3D con Operation=Subtraction,
	# nombrado DOOR_xxx, que además de servir de marcador le corta el hueco a
	# la pared) quedan anidadas adentro de la caja principal. Por eso la
	# búsqueda es recursiva, igual que en el addon real (find_children).
	#
	# El nodo raíz de la sala está CENTRADO en su caja en X/Z (igual que un
	# CSGBox3D), pero en Y usa el piso de ABAJO como referencia (0 = superficie
	# del piso más bajo que ocupa la sala) — así es como grid_position.y
	# coloca la sala en _build_scene. Por eso X/Z se miden como "porcentaje
	# centrado" pero Y se mide desde 0 hacia arriba, sin centrar. El resultado
	# queda expresado en la misma base 0..size-1 que usa el resto del
	# generador (idéntico al criterio del addon SimpleDungeons real).
	var full_size := Vector3(size_in_voxels) * voxel_scale
	var half_size_xz := Vector2(full_size.x, full_size.z) / 2.0
	for node in find_children("DOOR*", "Node3D", true, false):
		var door_node := node as Node3D
		var optional := door_node.name.begins_with("DOOR?")
		# Posición/rotación relativas a ESTA sala (no al padre inmediato de la
		# puerta, que puede ser la caja principal y no la sala en sí).
		var rel := _transform_relative_to_room(door_node)
		var pct_across := Vector3(
			(rel.origin.x + half_size_xz.x) / full_size.x,
			rel.origin.y / full_size.y,
			(rel.origin.z + half_size_xz.y) / full_size.z
		)
		var local_cell := Vector3i(
			clampi(int(floor(pct_across.x * size_in_voxels.x)), 0, size_in_voxels.x - 1),
			clampi(int(floor(pct_across.y * size_in_voxels.y)), 0, size_in_voxels.y - 1),
			clampi(int(floor(pct_across.z * size_in_voxels.z)), 0, size_in_voxels.z - 1)
		)
		var dir := _direction_from_rotation(rel.basis.get_euler().y)
		doors.append({
			"node": door_node,
			"local_cell": local_cell,
			"direction": dir,
			"optional": optional,
		})

## Compone los transforms LOCALES desde `node` hasta esta sala (sin usar
## global_transform, que no siempre está listo si la sala todavía no entró
## al árbol de escena — el generador detecta las puertas ANTES de eso).
func _transform_relative_to_room(node: Node3D) -> Transform3D:
	var t := Transform3D()
	var current: Node = node
	while current != self and current != null:
		if current is Node3D:
			t = (current as Node3D).transform * t
		current = current.get_parent()
	return t

func _direction_from_rotation(rot_y: float) -> Vector3i:
	# Normaliza el ángulo a uno de los 4 lados cardinales de la grilla.
	# OJO: convención propia en sentido HORARIO (90° = este), NO la de Godot
	# (donde rotation.y = 90° apunta el -Z del nodo hacia el oeste). Al cortar
	# huecos con una caja simétrica da igual visualmente, pero el valor sí
	# importa para la lógica: puerta en cara +X => 90, en cara -X => 270.
	var deg := int(round(rad_to_deg(rot_y))) % 360
	if deg < 0:
		deg += 360
	match deg:
		0:
			return Vector3i(0, 0, -1)
		90:
			return Vector3i(1, 0, 0)
		180:
			return Vector3i(0, 0, 1)
		270:
			return Vector3i(-1, 0, 0)
		_:
			return Vector3i(0, 0, -1)

## Rota un Vector3i sobre el plano X-Z en pasos de 90°. El componente Y no se
## toca nunca. Se usa para direcciones (vectores), no para índices de celda.
## 0°=(0,0,-1) -> 90°=(1,0,0) -> 180°=(0,0,1) -> 270°=(-1,0,0)
static func rotate_xz(v: Vector3i, steps: int) -> Vector3i:
	var x := v.x
	var z := v.z
	var n := ((steps % 4) + 4) % 4
	for i in range(n):
		var new_x := -z
		var new_z := x
		x = new_x
		z = new_z
	return Vector3i(x, v.y, z)

## Rota un índice de celda de ESQUINA (0..size-1, no un vector centrado) en
## pasos de 90°, dado el tamaño de la sala ANTES de rotar. A diferencia de
## rotate_xz (pensada para vectores/direcciones), acá hay que "reflejar y
## reacomodar" contra el tamaño porque el índice 0 no está en el centro de
## rotación sino en una esquina — rotarlo como vector daría índices fuera de
## la sala (incluso negativos) en cuanto la sala tuviera alguna rotación.
static func rotate_local_cell(cell: Vector3i, original_size: Vector3i, steps: int) -> Vector3i:
	var n := ((steps % 4) + 4) % 4
	match n:
		0:
			return cell
		1:
			return Vector3i(original_size.z - 1 - cell.z, cell.y, cell.x)
		2:
			return Vector3i(original_size.x - 1 - cell.x, cell.y, original_size.z - 1 - cell.z)
		_:
			return Vector3i(cell.z, cell.y, original_size.x - 1 - cell.x)

## Tamaño de la sala ANTES de la rotación que le aplicó el generador (deshace
## el swap x/z que se guardó en size_in_voxels al colocarla rotada).
func _pre_rotation_size() -> Vector3i:
	if placement_rot_steps % 2 == 1:
		return Vector3i(size_in_voxels.z, size_in_voxels.y, size_in_voxels.x)
	return size_in_voxels

## Celda GLOBAL (en la grilla del dungeon) donde está la puerta misma, ya
## considerando la rotación real que tiene la sala colocada.
func door_grid_pos(door: Dictionary) -> Vector3i:
	var rotated_cell := rotate_local_cell(door["local_cell"], _pre_rotation_size(), placement_rot_steps)
	return grid_position + rotated_cell

## Celda inmediatamente afuera de la puerta (el "portal" por donde sale el pasillo).
func door_exit_grid_pos(door: Dictionary) -> Vector3i:
	return door_grid_pos(door) + rotate_xz(door["direction"], placement_rot_steps)

## True si esta sala tiene una puerta ubicada en `own_cell` cuya salida apunta
## exactamente a `target_cell`. Lo usa el AStar3D del generador para decidir
## si se puede cruzar el límite de una sala en ese punto.
func has_door_towards(own_cell: Vector3i, target_cell: Vector3i) -> bool:
	for door in doors:
		if door_grid_pos(door) == own_cell and door_exit_grid_pos(door) == target_cell:
			return true
	return false

## AABB de la sala en la grilla del dungeon. Si `include_doors` es true, se
## expande para incluir la celda de salida de cada puerta obligatoria (y de
## las opcionales también si es una sala de escalera), dejándoles espacio
## libre para no quedar "tapadas" por otra sala pegada justo ahí.
func get_grid_aabbi(include_doors: bool) -> AABBi:
	var aabbi := AABBi.new(grid_position, size_in_voxels)
	if include_doors:
		for door in doors:
			if door["optional"] and not is_stair_room:
				continue
			aabbi = aabbi.expand_to_include(door_exit_grid_pos(door))
	return aabbi

## True si esta sala se solapa con `other`: o bien sus cajas se cruzan
## directamente (contando `extra_margin` celdas de colchón alrededor, para
## que además de no pisarse queden separadas y dejen lugar a un pasillo
## visible), o bien una puerta de una desemboca dentro del área de la otra
## sin que haya una puerta que la reciba justo ahí.
func overlaps_room(other: DungeonRoom, extra_margin: int = 0) -> bool:
	var a := get_grid_aabbi(false)
	var b := other.get_grid_aabbi(false)
	if extra_margin > 0 and a.grow_xz(extra_margin).intersects(b):
		return true
	if a.intersects(b):
		return true
	for door in doors:
		if door["optional"] and not is_stair_room:
			continue
		var exit_cell := door_exit_grid_pos(door)
		if b.contains_point(exit_cell) and not other.has_door_towards(exit_cell, door_grid_pos(door)):
			return true
	for door in other.doors:
		if door["optional"] and not other.is_stair_room:
			continue
		var exit_cell := other.door_exit_grid_pos(door)
		if a.contains_point(exit_cell) and not has_door_towards(exit_cell, other.door_grid_pos(door)):
			return true
	return false

## Empuja esta sala en X/Z para alejarla de `other`, sin salirse de `bounds`
## (los límites del dungeon). El eje Y nunca se toca. Se llama repetidamente
## desde el generador hasta que ya no queden solapes.
func push_away_from_and_stay_within_bounds(other: DungeonRoom, bounds: AABBi) -> void:
	var my_center := Vector3(grid_position) + Vector3(size_in_voxels) / 2.0
	var other_center := Vector3(other.grid_position) + Vector3(other.size_in_voxels) / 2.0
	var diff := other_center - my_center
	var move := Vector3i(
		-1 if diff.x > 0 else 1,
		0,
		-1 if diff.z > 0 else 1
	)
	var dpos := get_grid_aabbi(true)
	var pushed := dpos.translated(move).push_within(bounds, true)
	var able_to_move := pushed.position - dpos.position
	if able_to_move.x != 0 or able_to_move.z != 0:
		grid_position += able_to_move
