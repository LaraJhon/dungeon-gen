class_name DungeonAStar3D
extends AStar3D
## AStar3D global sobre TODA la grilla del dungeon, con el mismo criterio de
## costos que usa el addon SimpleDungeons real: caminar por dentro de una
## sala o de un pasillo ya construido es más barato que abrir camino nuevo.
## Eso hace que, al conectar muchas salas, los pasillos tiendan a fusionarse
## en corredores compartidos en vez de quedar duplicados uno al lado del otro.
##
## Reglas de movimiento (idénticas al addon):
##   - Afuera de cualquier sala: solo se puede caminar en horizontal.
##   - Dentro de LA MISMA sala: se puede ir a cualquier celda vecina, incluso
##     verticalmente (así es como funcionan las escaleras).
##   - Al cruzar el borde de una sala (hacia afuera o hacia otra sala): solo
##     si hay una puerta real de esa sala apuntando exactamente ahí.
## Regla extra (pasillos anchos/altos): una celda de pasillo solo se puede
## usar si el pasillo completo (clearance_radius celdas a cada lado y
## clearance_height pisos de alto) entra ahí sin tocar ninguna sala ni salirse
## del dungeon. Las celdas de salida de las puertas quedan exentas.

var heuristic_mode: int = 2 # 0 = Dijkstra (sin heurística), 1 = Manhattan, 2 = Euclidiana
var heuristic_scale: float = 1.0
var room_cost_multiplier: float = 0.25
var corridor_cost_multiplier: float = 0.25
var room_cost_multiplier_for_required_doors: float = 2.0
var use_required_doors_cost: bool = false

var _cell_to_room: Dictionary   # Vector3i -> DungeonRoom (celdas de sala, sin contar pasillos)
var _corridor_cells: Dictionary # Vector3i -> true (celdas ya convertidas en pasillo)
var _pos_to_id: Dictionary
var _id_to_pos: Dictionary
var _dungeon_size: Vector3i
var _clearance_radius: int
var _clearance_height: int
var _exempt_cells: Dictionary # Vector3i -> true (salidas de puertas)
var _clearance_cache: Dictionary = {}

func _init(dungeon_size: Vector3i, cell_to_room: Dictionary, corridor_cells: Dictionary,
		clearance_radius: int = 0, clearance_height: int = 1, exempt_cells: Dictionary = {}) -> void:
	_cell_to_room = cell_to_room
	_corridor_cells = corridor_cells
	_dungeon_size = dungeon_size
	_clearance_radius = clearance_radius
	_clearance_height = max(1, clearance_height)
	_exempt_cells = exempt_cells

	var id := 0
	for x in range(dungeon_size.x):
		for y in range(dungeon_size.y):
			for z in range(dungeon_size.z):
				var cell := Vector3i(x, y, z)
				add_point(id, Vector3(cell))
				_pos_to_id[cell] = id
				_id_to_pos[id] = cell
				id += 1

	var dirs := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]
	for x in range(dungeon_size.x):
		for y in range(dungeon_size.y):
			for z in range(dungeon_size.z):
				var cell := Vector3i(x, y, z)
				for dir in dirs:
					var neighbor: Vector3i = cell + dir
					if _pos_to_id.has(neighbor) and _can_walk(cell, neighbor):
						connect_points(_pos_to_id[cell], _pos_to_id[neighbor], false)

func _can_walk(a: Vector3i, b: Vector3i) -> bool:
	var room_a: DungeonRoom = _cell_to_room.get(a)
	var room_b: DungeonRoom = _cell_to_room.get(b)
	if room_a == null and room_b == null:
		return a.y == b.y and _has_clearance(a) and _has_clearance(b)
	if room_a == room_b:
		return true
	var fits_a: bool = room_a == null or room_a.has_door_towards(a, b)
	var fits_b: bool = room_b == null or room_b.has_door_towards(b, a)
	return fits_a and fits_b

## True si un pasillo de ancho/alto completo cabe centrado en `cell`.
func _has_clearance(cell: Vector3i) -> bool:
	if _exempt_cells.has(cell):
		return true
	if _clearance_cache.has(cell):
		return _clearance_cache[cell]
	var ok := true
	for dx in range(-_clearance_radius, _clearance_radius + 1):
		for dz in range(-_clearance_radius, _clearance_radius + 1):
			for h in range(_clearance_height):
				var c := cell + Vector3i(dx, h, dz)
				if c.x < 0 or c.z < 0 or c.x >= _dungeon_size.x or c.z >= _dungeon_size.z \
						or c.y >= _dungeon_size.y or _cell_to_room.has(c):
					ok = false
					break
			if not ok:
				break
		if not ok:
			break
	_clearance_cache[cell] = ok
	return ok

func _compute_cost(from_id: int, to_id: int) -> float:
	var to_pos: Vector3i = _id_to_pos[to_id]
	var cost := (get_point_position(to_id) - get_point_position(from_id)).length()
	if _cell_to_room.has(to_pos):
		cost *= room_cost_multiplier_for_required_doors if use_required_doors_cost else room_cost_multiplier
	elif _corridor_cells.has(to_pos):
		cost *= corridor_cost_multiplier
	return cost

func _estimate_cost(from_id: int, to_id: int) -> float:
	if heuristic_mode == 0:
		return 0.0
	var diff: Vector3 = get_point_position(to_id) - get_point_position(from_id)
	if heuristic_mode == 1:
		return (abs(diff.x) + abs(diff.y) + abs(diff.z)) * heuristic_scale
	return diff.length() * heuristic_scale

func path_between(a: Vector3i, b: Vector3i) -> PackedVector3Array:
	if not _pos_to_id.has(a) or not _pos_to_id.has(b):
		return PackedVector3Array()
	return get_point_path(_pos_to_id[a], _pos_to_id[b])
