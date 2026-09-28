extends DungeonRoom
## Script de PRUEBA temporal, solo para verificar que las puertas se detectan bien.
## Attachalo en vez de DungeonRoom.gd directo, corré la escena (F6) y mirá la consola.
## Cuando confirmes que anda, volvé a attachar DungeonRoom.gd normal (sin este print).

func _ready() -> void:
	super._ready() # importante: llama al _ready() de DungeonRoom que detecta las puertas
	print("--- Puertas detectadas ---")
	print("Cantidad: ", doors.size())
	for d in doors:
		print("  Nodo: ", d["node"].name, " | celda local: ", d["local_cell"], " | dirección: ", d["direction"])
