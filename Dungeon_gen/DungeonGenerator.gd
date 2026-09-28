extends Node3D
class_name DungeonGenerator
## Generador procedural de dungeons 3D con soporte multi-piso (Y+ y Y-).
## Réplica del algoritmo del addon SimpleDungeons (portado a código plano,
## sin plugin/threading/multijugador), en 4 etapas:
##
##   1. Coloca `room_count` habitaciones en posiciones y rotaciones al azar,
##      SIN chequear solapes todavía (igual que el addon: resolver el solape
##      es trabajo de la etapa de separación, no de la colocación).
##   2. Coloca salas de escalera (is_stair_room) hasta que todos los pisos
##      usados por alguna sala queden conectados entre sí. Si el "salto" de
##      piso a piso de una sola escalera no alcanza para unir dos pisos
##      lejanos, va encadenando varias (heurística, no exhaustiva).
##   3. Separa las salas solapadas: por cada par que se pisa, las empuja en
##      X/Z en direcciones opuestas, respetando los límites del dungeon.
##      Se repite hasta que no quede ningún solape (o se agote el margen de
##      iteraciones de seguridad).
##   4. Conecta todas las salas con UN SOLO AStar3D global sobre la grilla
##      completa, cuya función de costo hace más barato caminar por dentro
##      de salas/pasillos ya existentes. Esto tiende a fusionar los pasillos
##      en corredores compartidos en vez de duplicarlos. Al final, une
##      cualquier puerta obligatoria que haya quedado suelta.
##
## Si algo queda sin conectar, reintenta la generación completa hasta
## `max_retries` veces antes de darse por vencido.

signal done_generating

@export var room_scenes: Array[PackedScene] = []
## Escena de 1 celda para los pasillos (centrada en X/Z, base en Y=0). Debe
## tener una pared por lado con nombre exacto PARED_N, PARED_S, PARED_E y
## PARED_O, más PISO y TECHO: el generador borra las que quedan "adentro"
## del pasillo (donde continúa, donde hay una puerta, o entre los pisos de un
## pasillo alto). Todo lo demás (decoración, luces) queda siempre.
@export var corridor_piece_scene: PackedScene
## Ancho de los pasillos en celdas (impar: 1, 3, 5...). Solo afecta la
## geometría; el camino se calcula igual con 1 celda. Donde hay una sala al
## lado, el pasillo se angosta solo para no pisarla.
@export var corridor_width: int = 3
## Alto de los pasillos en pisos (1 = 4 m, 2 = 8 m...).
@export var corridor_height: int = 2
@export var room_count: int = 8
@export var dungeon_size: Vector3i = Vector3i(20, 3, 20) ## y > 1 habilita múltiples pisos.
@export var voxel_scale: Vector3 = Vector3(4, 4, 4)
@export var generate_seed: int = 0 ## 0 = aleatorio
@export var max_retries: int = 6 ## Reintentos completos si algo queda sin conectar.
@export var max_separation_iterations: int = 2000
## Celdas de colchón que se exigen entre dos salas (además de no solaparse),
## para que quede lugar visible para un pasillo entre ellas.
@export var min_room_gap: int = 2
## Dibuja las líneas de la grilla del dungeon (una por celda, por piso), para
## verificar visualmente que todo cae alineado a la grilla.
@export var show_debug_grid: bool = true

@export_group("Conexión de pasillos (AStar3D)")
enum AStarHeuristic { NONE_DIJKSTRA = 0, MANHATTAN = 1, EUCLIDEAN = 2 }
## Euclidiana: corredores más rectos. Manhattan: puede zigzaguear. Dijkstra: siempre el camino más corto exacto, pero puede zigzaguear más.
@export var astar_heuristic: AStarHeuristic = AStarHeuristic.EUCLIDEAN
@export var heuristic_scale: float = 1.0
## Costo de caminar por una celda de pasillo YA construida. Más bajo = los pasillos nuevos tienden a fusionarse con los existentes.
@export var corridor_cost_multiplier: float = 0.25
## Costo de caminar por dentro de una sala (no pasillo) para llegar a otra. Más bajo = se ahorran pasillos reusando salas, pero la conexión puede quedar invisible (cruza varias salas sin abrir ningún pasillo nuevo). Más alto = prioriza pasillo visible.
@export var room_cost_multiplier: float = 1.5
## Al final, costo de cruzar salas para cerrar puertas obligatorias sueltas. Más alto = prioriza pasillos nuevos antes que atravesar salas.
@export var room_cost_at_end_for_required_doors: float = 2.0

## Nombre del nodo-pared de corridor_piece_scene para cada lado de la celda.
const CORRIDOR_SIDES := {
	"PARED_N": Vector3i(0, 0, -1),
	"PARED_S": Vector3i(0, 0, 1),
	"PARED_E": Vector3i(1, 0, 0),
	"PARED_O": Vector3i(-1, 0, 0),
}

var _rng := RandomNumberGenerator.new()
var _rooms: Array[DungeonRoom] = []
var _corridor_cells: Array = []
var _normal_scenes: Array[PackedScene] = []
var _normal_weights: Array[float] = [] # spawn_weight de cada escena de _normal_scenes
var _normal_limits: Array[int] = [] # max_per_dungeon de cada escena (0 = sin límite)
var _stair_gap_infos: Array = [] # [{ "scene", "size", "bottom_local_y", "gap" }]
## Pisos libres que tiene que haber ARRIBA de cualquier puerta: para la parte
## alta de los pasillos (corridor_height) y para que entre una escalera que
## llegue a ese piso (las escaleras pueden ser más altas que su salto).
var _door_headroom: int = 0

## Muestra u oculta la grilla de debug sin tener que regenerar todo el dungeon.
func set_debug_grid_visible(value: bool) -> void:
	show_debug_grid = value
	var grid_node := get_node_or_null("DebugGrid")
	if grid_node:
		grid_node.visible = value

## Punto razonable para "aparecer" y explorar el dungeon: adentro de la
## primera sala generada (evitando escaleras si hay alguna otra opción),
## a altura de ojos sobre su piso.
func get_spawn_position() -> Vector3:
	if _rooms.is_empty():
		return Vector3.ZERO
	var room := _rooms[0]
	for r in _rooms:
		if not r.is_stair_room:
			room = r
			break
	return room.position + Vector3(0, 3.0, 0)

func generate() -> void:
	_rng.seed = generate_seed if generate_seed != 0 else randi()
	_classify_room_scenes()

	var attempt := 0
	var connected := false
	while true:
		_clear_previous()
		_rooms = _place_rooms_randomly()
		_place_stairs()
		var separated := _separate_rooms()
		# Si quedaron salas encimadas no vale la pena conectar: se reintenta
		# directo (salvo en el último intento, donde se usa lo que haya).
		if not separated and attempt < max_retries:
			attempt += 1
			print("Dungeon: reintentando generación completa (%d/%d) por salas encimadas." % [attempt, max_retries])
			continue
		connected = _connect_rooms()
		if connected or attempt >= max_retries:
			break
		attempt += 1
		print("Dungeon: reintentando generación completa (%d/%d) por conexión incompleta." % [attempt, max_retries])

	if not connected:
		push_warning("El dungeon se generó pero alguna sala o puerta pudo haber quedado sin conectar.")

	_build_scene()
	done_generating.emit()

func _clear_previous() -> void:
	for c in get_children():
		remove_child(c) # saca el nodo del árbol YA (queue_free recién libera memoria al final del frame)
		c.queue_free()
	_rooms.clear()
	_corridor_cells.clear()

## Separa room_scenes en normales (para la colocación al azar) y de escalera
## (para la etapa 2), precalculando el "salto" de piso que puede cerrar cada
## tipo de escalera a partir de las posiciones Y de sus puertas.
func _classify_room_scenes() -> void:
	_normal_scenes.clear()
	_normal_weights.clear()
	_normal_limits.clear()
	_stair_gap_infos.clear()
	_door_headroom = max(0, corridor_height - 1)
	for scene in room_scenes:
		var probe := scene.instantiate() as DungeonRoom
		if probe == null:
			push_error("Una escena en room_scenes no hereda de DungeonRoom.")
			continue
		probe.detect_doors()
		if probe.is_stair_room:
			var floor_ys: Dictionary = {}
			for door in probe.doors:
				floor_ys[door["local_cell"].y] = true
			var ys: Array = floor_ys.keys()
			ys.sort()
			if ys.size() >= 2:
				_stair_gap_infos.append({
					"scene": scene,
					"size": probe.size_in_voxels,
					"bottom_local_y": ys[0],
					"gap": ys[ys.size() - 1] - ys[0],
				})
				_door_headroom = max(_door_headroom, probe.size_in_voxels.y - 1 - int(ys[ys.size() - 1]))
			else:
				push_warning("La sala de escalera %s no tiene puertas en 2 pisos distintos; se ignora." % scene.resource_path)
		else:
			_normal_scenes.append(scene)
			_normal_weights.append(probe.spawn_weight)
			_normal_limits.append(probe.max_per_dungeon)
		probe.queue_free()

# ---------------------------------------------------------------------------
# 1. Colocación al azar (sin chequeo de solape: eso lo resuelve la etapa 3)
# ---------------------------------------------------------------------------
func _place_rooms_randomly() -> Array[DungeonRoom]:
	var placed: Array[DungeonRoom] = []
	if _normal_scenes.is_empty():
		push_error("No hay escenas de habitaciones normales en room_scenes (¿todas están marcadas is_stair_room?).")
		return placed
	var counts: Dictionary = {} # resource_path -> veces colocada (así una escena repetida en el array comparte el límite)
	for i in range(room_count):
		var idx := _pick_weighted_scene(counts)
		if idx == -1:
			print("Dungeon: solo se colocaron %d de %d salas (todas las demás llegaron a su max_per_dungeon o tienen peso 0)." % [i, room_count])
			break
		var key := _normal_scenes[idx].resource_path
		counts[key] = counts.get(key, 0) + 1
		var scene: PackedScene = _normal_scenes[idx]
		var instance := scene.instantiate() as DungeonRoom
		if instance == null:
			push_error("Una escena en room_scenes no hereda de DungeonRoom.")
			continue
		instance.detect_doors() # clave: no esperamos a _ready(), lo necesitamos YA

		var rot_steps := _rng.randi_range(0, 3)
		var size := instance.size_in_voxels
		if rot_steps % 2 == 1:
			size = Vector3i(size.z, size.y, size.x) # swap x/z al rotar 90 o 270

		var pos_x := _rand_pos_with_margin(size.x, dungeon_size.x)
		var pos_z := _rand_pos_with_margin(size.z, dungeon_size.z)
		# Que ninguna puerta quede tan arriba que no entre el pasillo alto ni la
		# escalera que la conecte con el resto de los pisos.
		var top_door_y := 0
		for door in instance.doors:
			top_door_y = max(top_door_y, door["local_cell"].y)
		var max_y: int = min(dungeon_size.y - size.y, dungeon_size.y - 1 - _door_headroom - top_door_y)
		var pos_y := _rng.randi_range(0, max(0, max_y))

		instance.grid_position = Vector3i(pos_x, pos_y, pos_z)
		# Negativo: la lógica (rotate_xz / rotate_local_cell) gira en sentido
		# HORARIO visto desde arriba (norte -> este), pero rotation.y positivo
		# en Godot gira ANTIHORARIO (norte -> oeste). Sin el signo, en 90°/270°
		# la geometría queda espejada respecto de donde el generador cree que
		# están las puertas.
		instance.rotation.y = -deg_to_rad(rot_steps * 90.0)
		instance.placement_rot_steps = rot_steps
		instance.size_in_voxels = size
		placed.append(instance)

	return placed

## Sorteo ponderado por spawn_weight entre las escenas normales que todavía no
## llegaron a su max_per_dungeon. Devuelve el índice elegido, o -1 si no queda
## ninguna disponible.
func _pick_weighted_scene(counts: Dictionary) -> int:
	var total := 0.0
	for i in _normal_scenes.size():
		if _scene_available(i, counts):
			total += _normal_weights[i]
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	var last_available := -1
	for i in _normal_scenes.size():
		if not _scene_available(i, counts):
			continue
		last_available = i
		roll -= _normal_weights[i]
		if roll < 0.0:
			return i
	return last_available # por redondeo de floats

func _scene_available(i: int, counts: Dictionary) -> bool:
	if _normal_weights[i] <= 0.0:
		return false
	return _normal_limits[i] <= 0 or counts.get(_normal_scenes[i].resource_path, 0) < _normal_limits[i]

## Elige una posición aleatoria dejando 1 celda de margen respecto al borde
## del dungeon en ese eje, para que ninguna puerta pueda apuntar fuera de la
## grilla entera (lo cual la dejaría imposible de conectar).
func _corridor_radius() -> int:
	return max(0, (corridor_width - 1) / 2)

## Celdas libres entre una sala y la orilla del dungeon: lo que ocupa medio
## pasillo ancho + la celda de salida de la puerta + 1 de aire.
func _edge_margin() -> int:
	return max(1, _corridor_radius() + 2)

## Separación mínima entre salas: al menos lo que mide un pasillo de ancho,
## para que siempre pueda pasar uno completo entre dos salas.
func _room_gap() -> int:
	return max(min_room_gap, corridor_width)

func _rand_pos_with_margin(size_comp: int, dungeon_comp: int) -> int:
	var margin := _edge_margin()
	var lo := margin
	var hi := dungeon_comp - size_comp - margin
	if hi < lo:
		lo = 0
		hi = max(0, dungeon_comp - size_comp)
	return _rng.randi_range(lo, hi)

# ---------------------------------------------------------------------------
# 2. Escaleras: conecta todos los pisos usados por alguna sala entre sí.
# ---------------------------------------------------------------------------
func _place_stairs() -> void:
	if _stair_gap_infos.is_empty():
		return

	var floor_graph := TreeGraph.new()
	for room in _rooms:
		var floors_here: Dictionary = {}
		for door in room.doors:
			floors_here[room.grid_position.y + door["local_cell"].y] = true
		var floors_arr: Array = floors_here.keys()
		for f in floors_arr:
			if not floor_graph.has_node(f):
				floor_graph.add_node(f)
		for i in range(1, floors_arr.size()):
			floor_graph.connect_nodes(floors_arr[0], floors_arr[i])

	if floor_graph.get_all_nodes().size() <= 1:
		return # dungeon de un solo piso, no hace falta ninguna escalera

	var safety := 0
	var max_safety := 300
	while not floor_graph.is_fully_connected() and safety < max_safety:
		safety += 1
		var nodes: Array = floor_graph.get_all_nodes().duplicate()
		nodes.sort()
		var placed_one := false
		for f1 in nodes:
			for info in _stair_gap_infos:
				var f2: int = f1 + info["gap"]
				if f2 < 0 or f2 >= dungeon_size.y:
					continue
				if floor_graph.has_node(f2) and floor_graph.are_nodes_connected(f1, f2):
					continue
				var size: Vector3i = info["size"]
				var y_pos: int = f1 - info["bottom_local_y"]
				if y_pos < 0 or y_pos + size.y > dungeon_size.y:
					continue
				_spawn_stair(info["scene"], size, y_pos)
				if not floor_graph.has_node(f2):
					floor_graph.add_node(f2)
				floor_graph.connect_nodes(f1, f2)
				placed_one = true
				break
			if placed_one:
				break
		if not placed_one:
			push_warning("No se pudieron conectar todos los pisos: agregá una escalera cuyo salto (gap) permita unir los pisos restantes.")
			break

func _spawn_stair(scene: PackedScene, size: Vector3i, y_pos: int) -> void:
	var instance := scene.instantiate() as DungeonRoom
	instance.detect_doors()
	var rot_steps := _rng.randi_range(0, 3)
	var rotated_size := size
	if rot_steps % 2 == 1:
		rotated_size = Vector3i(size.z, size.y, size.x)
	var pos_x := _rand_pos_with_margin(rotated_size.x, dungeon_size.x)
	var pos_z := _rand_pos_with_margin(rotated_size.z, dungeon_size.z)
	instance.grid_position = Vector3i(pos_x, y_pos, pos_z)
	instance.rotation.y = -deg_to_rad(rot_steps * 90.0) # ver nota de signo en _place_rooms_randomly
	instance.placement_rot_steps = rot_steps
	instance.size_in_voxels = rotated_size
	_rooms.append(instance)

# ---------------------------------------------------------------------------
# 3. Separación: empuja las salas solapadas hasta que no quede ningún solape.
# ---------------------------------------------------------------------------
func _separate_rooms() -> bool:
	# Las salas no pueden quedar a menos de _edge_margin() celdas de la orilla,
	# ni siquiera cuando la separación las empuja.
	var m := _edge_margin()
	var bounds := AABBi.new(Vector3i(m, 0, m), dungeon_size - Vector3i(2 * m, 0, 2 * m))
	if bounds.size.x <= 0 or bounds.size.z <= 0:
		bounds = AABBi.new(Vector3i.ZERO, dungeon_size)
	var gap := _room_gap()
	var safety := 0
	while safety < max_separation_iterations:
		safety += 1
		var any_overlap := false
		for i in range(_rooms.size()):
			for j in range(i + 1, _rooms.size()):
				if _rooms[i].overlaps_room(_rooms[j], gap):
					_rooms[i].push_away_from_and_stay_within_bounds(_rooms[j], bounds)
					_rooms[j].push_away_from_and_stay_within_bounds(_rooms[i], bounds)
					any_overlap = true
		if not any_overlap:
			print("Dungeon: separación convergió en %d iteración/es (%d salas)." % [safety, _rooms.size()])
			return true

	# Se agotaron las iteraciones con solapes todavía sin resolver: reportamos
	# exactamente cuáles, porque un solape residual rompe el registro de
	# puertas de esa sala (queda "invisible" para el AStar de conexión).
	var still_overlapping: Array = []
	for i in range(_rooms.size()):
		for j in range(i + 1, _rooms.size()):
			if _rooms[i].overlaps_room(_rooms[j], gap):
				still_overlapping.append("%s <-> %s" % [_rooms[i].name, _rooms[j].name])
	print("Dungeon: la separación NO convergió tras %d iteraciones. Pares con solape residual: %s" % [max_separation_iterations, still_overlapping])
	push_warning("La separación de salas no convergió tras %d iteraciones; puede quedar algún solape leve." % max_separation_iterations)
	return false

# ---------------------------------------------------------------------------
# 4. Conexión: un solo AStar3D global con costos que fusionan pasillos.
# ---------------------------------------------------------------------------
func _connect_rooms() -> bool:
	if _rooms.size() <= 1:
		return true

	var cell_to_room: Dictionary = {}
	var claimed_by_two_rooms := 0
	for room in _rooms:
		var aabbi := room.get_grid_aabbi(false)
		for x in range(aabbi.size.x):
			for y in range(aabbi.size.y):
				for z in range(aabbi.size.z):
					var cell := aabbi.position + Vector3i(x, y, z)
					if cell_to_room.has(cell) and cell_to_room[cell] != room:
						claimed_by_two_rooms += 1
					cell_to_room[cell] = room
	if claimed_by_two_rooms > 0:
		print("Dungeon: %d celda(s) reclamadas por dos salas a la vez (solape residual de la separación) — esas salas pueden quedar mal conectadas." % claimed_by_two_rooms)

	var corridor_cells: Dictionary = {}
	# Las celdas de salida de las puertas quedan exentas del chequeo de espacio
	# (el pasillo tiene que poder pegarse a la pared justo ahí).
	var door_exits: Dictionary = {}
	for room in _rooms:
		for door in room.doors:
			door_exits[room.door_exit_grid_pos(door)] = true
	var astar := DungeonAStar3D.new(dungeon_size, cell_to_room, corridor_cells,
			_corridor_radius(), corridor_height, door_exits)
	astar.heuristic_mode = astar_heuristic
	astar.heuristic_scale = heuristic_scale
	astar.room_cost_multiplier = room_cost_multiplier
	astar.corridor_cost_multiplier = corridor_cost_multiplier
	astar.room_cost_multiplier_for_required_doors = room_cost_at_end_for_required_doors

	# Crece un único grupo conectado (estilo Prim): cada sala suelta se une a
	# CUALQUIERA de las ya conectadas (no solo "a la siguiente de la lista"),
	# así ninguna queda huérfana solo porque su primer intento de camino
	# falló. Se reintenta contra todo el grupo conectado antes de rendirse.
	var rooms_with_doors: Array[DungeonRoom] = []
	for room in _rooms:
		if room.doors.size() > 0:
			rooms_with_doors.append(room)

	var success := true
	if rooms_with_doors.size() >= 2:
		var connected: Array[DungeonRoom] = [rooms_with_doors[0]]
		var remaining: Array[DungeonRoom] = rooms_with_doors.slice(1)
		while remaining.size() > 0:
			var joined := false
			for r in remaining:
				for c in connected:
					var path := astar.path_between(r.get_grid_aabbi(false).position, c.get_grid_aabbi(false).position)
					if path.size() > 0:
						_carve_path(path, cell_to_room, corridor_cells)
						connected.append(r)
						remaining.erase(r)
						joined = true
						break
				if joined:
					break
			if not joined:
				var stuck_names: Array = remaining.map(func(r2): return r2.name)
				print("Dungeon: no se encontró camino desde el grupo conectado (%d salas) hacia: %s" % [connected.size(), stuck_names])
				push_warning("%d sala(s) quedaron sin ningún camino posible hacia el resto del dungeon." % remaining.size())
				success = false
				break
		print("Dungeon: %d/%d salas quedaron en el grupo principal conectado." % [connected.size(), rooms_with_doors.size()])

	# Puede quedar alguna puerta obligatoria suelta (nunca quedó del lado
	# "activo" de la cadena anterior). Conectamos cada una a la puerta más
	# cercana de otra sala, penalizando cruzar salas en esta fase final.
	var required_doors := _collect_required_doors()
	astar.use_required_doors_cost = true
	for door_info in required_doors:
		if cell_to_room.has(door_info["exit"]) or corridor_cells.has(door_info["exit"]):
			continue
		var candidates: Array = required_doors.filter(func(o): return o != door_info)
		if candidates.is_empty():
			continue
		candidates.sort_custom(func(a, b): return _door_sort_key(door_info, a) < _door_sort_key(door_info, b))
		var path := astar.path_between(door_info["exit"], candidates[0]["exit"])
		if path.size() == 0:
			push_warning("No se pudo conectar una puerta obligatoria de %s." % door_info["room"].name)
			success = false
			continue
		_carve_path(path, cell_to_room, corridor_cells)

	_corridor_cells = corridor_cells.keys()
	return success

func _carve_path(path: PackedVector3Array, cell_to_room: Dictionary, corridor_cells: Dictionary) -> void:
	for p in path:
		var cell := Vector3i(round(p.x), round(p.y), round(p.z))
		if not cell_to_room.has(cell) and not corridor_cells.has(cell):
			corridor_cells[cell] = true

func _collect_required_doors() -> Array:
	var result: Array = []
	for room in _rooms:
		for door in room.doors:
			if door["optional"]:
				continue
			var exit_cell: Vector3i = room.door_exit_grid_pos(door)
			if exit_cell.x < 0 or exit_cell.y < 0 or exit_cell.z < 0 \
					or exit_cell.x >= dungeon_size.x or exit_cell.y >= dungeon_size.y or exit_cell.z >= dungeon_size.z:
				continue # la puerta apunta fuera de la grilla entera; no se puede conectar
			result.append({"room": room, "door": door, "exit": exit_cell})
	return result

func _door_sort_key(a: Dictionary, b: Dictionary) -> float:
	var dist: float = Vector3(b["exit"] - a["exit"]).length()
	if b["room"] == a["room"] or b["exit"].y != a["exit"].y:
		dist += dungeon_size.x + dungeon_size.y + dungeon_size.z
	return dist

# ---------------------------------------------------------------------------
# Instanciar habitaciones y pasillos en la escena
# ---------------------------------------------------------------------------
func _build_scene() -> void:
	var rooms_container := Node3D.new()
	rooms_container.name = "RoomsContainer"
	add_child(rooms_container)
	for room in _rooms:
		rooms_container.add_child(room)
		# grid_position es la ESQUINA (mínimo corner) de la sala en X/Z,
		# pero las salas están armadas con su piso CENTRADO en el origen
		# local. Por eso sumamos medio tamaño en X/Z para que coincida con
		# la grilla lógica. En Y se deja tal cual (esquina = base de la sala).
		var half_extent := Vector3(
			room.size_in_voxels.x * voxel_scale.x / 2.0,
			0.0,
			room.size_in_voxels.z * voxel_scale.z / 2.0
		)
		room.position = GridUtils.grid_to_world(room.grid_position, voxel_scale) + half_extent

	var debug_grid := DungeonDebugGrid.new()
	debug_grid.name = "DebugGrid"
	add_child(debug_grid)
	debug_grid.rebuild(dungeon_size, voxel_scale)
	debug_grid.visible = show_debug_grid

	if corridor_piece_scene == null:
		push_warning("No asignaste corridor_piece_scene: se generó la grilla de pasillos pero no hay geometría para instanciar.")
		return

	# Celda de salida de cada puerta -> celdas de sala a las que da esa puerta
	# (para saber hacia qué lado un pasillo tiene que quedar abierto).
	var door_links: Dictionary = {}
	for room in _rooms:
		for door in room.doors:
			var exit_cell: Vector3i = room.door_exit_grid_pos(door)
			if not door_links.has(exit_cell):
				door_links[exit_cell] = []
			door_links[exit_cell].append(room.door_grid_pos(door))
			if room.tall_doors:
				for h in range(1, corridor_height):
					var up := Vector3i(0, h, 0)
					if not door_links.has(exit_cell + up):
						door_links[exit_cell + up] = []
					door_links[exit_cell + up].append(room.door_grid_pos(door) + up)

	# El AStar trabaja con pasillos de 1 celda; acá se "engordan" solo para la
	# geometría: cada celda del camino se expande a corridor_width celdas de
	# ancho (en X y Z) y corridor_height pisos de alto, sin pisar ninguna sala.
	var room_cells: Dictionary = {}
	for room in _rooms:
		var aabbi := room.get_grid_aabbi(false)
		for x in range(aabbi.size.x):
			for y in range(aabbi.size.y):
				for z in range(aabbi.size.z):
					room_cells[aabbi.position + Vector3i(x, y, z)] = true
	var bounds := AABBi.new(Vector3i.ZERO, dungeon_size)
	var radius: int = max(0, (corridor_width - 1) / 2)

	var base_set: Dictionary = {} # celdas por donde se camina (piso del pasillo)
	for cell in _corridor_cells:
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var c: Vector3i = cell + Vector3i(dx, 0, dz)
				if bounds.contains_point(c) and not room_cells.has(c):
					base_set[c] = true

	var upper_set: Dictionary = {} # celdas agregadas encima, solo para dar altura
	for cell in base_set:
		for h in range(1, corridor_height):
			var c: Vector3i = cell + Vector3i(0, h, 0)
			if not bounds.contains_point(c) or room_cells.has(c) or base_set.has(c):
				break
			upper_set[c] = true

	var corridors_container := Node3D.new()
	corridors_container.name = "CorridorsContainer"
	add_child(corridors_container)
	var cell_center_offset := Vector3(voxel_scale.x / 2.0, 0.0, voxel_scale.z / 2.0)
	for is_upper in [false, true]:
		var layer: Dictionary = upper_set if is_upper else base_set
		for cell in layer:
			var piece := corridor_piece_scene.instantiate() as Node3D
			# La pieza trae una pared por lado (PARED_N/S/E/O) más PISO y TECHO.
			# Se quita cada una que separe esta celda de otra del mismo pasillo
			# (o de la sala, si justo ahí desemboca una puerta).
			for side in CORRIDOR_SIDES:
				var neighbor: Vector3i = cell + CORRIDOR_SIDES[side]
				var open: bool = layer.has(neighbor) \
						or (door_links.has(cell) and door_links[cell].has(neighbor))
				if open:
					_remove_piece_part(piece, side)
			if is_upper:
				_remove_piece_part(piece, "PISO")
			if upper_set.has(cell + Vector3i(0, 1, 0)):
				_remove_piece_part(piece, "TECHO")
			corridors_container.add_child(piece)
			piece.position = GridUtils.grid_to_world(cell, voxel_scale) + cell_center_offset
	print("Dungeon: %d celdas de camino -> %d piezas de pasillo (ancho %d, alto %d)." % [_corridor_cells.size(), base_set.size() + upper_set.size(), corridor_width, corridor_height])

func _remove_piece_part(piece: Node, part_name: String) -> void:
	var part := piece.get_node_or_null(part_name)
	if part:
		piece.remove_child(part)
		part.free()
