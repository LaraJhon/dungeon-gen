class_name TreeGraph
## Union-Find genérico. El generador lo usa para saber qué pisos del dungeon
## ya quedaron conectados entre sí a través de alguna sala de escalera.

var _nodes: Array = []
var _roots: Dictionary = {}

func add_node(node) -> void:
	_nodes.append(node)
	_roots[node] = node

func has_node(node) -> bool:
	return node in _nodes

func get_all_nodes() -> Array:
	return _nodes

func find_root(node):
	if _roots[node] != node:
		_roots[node] = find_root(_roots[node]) # compresión de camino
	return _roots[node]

func connect_nodes(node_a, node_b) -> void:
	var root_a = find_root(node_a)
	var root_b = find_root(node_b)
	if root_a != root_b:
		_roots[root_a] = root_b

func are_nodes_connected(node_a, node_b) -> bool:
	return find_root(node_a) == find_root(node_b)

func is_fully_connected() -> bool:
	return _nodes.size() == 0 or _nodes.all(func(node): return are_nodes_connected(node, _nodes[0]))
