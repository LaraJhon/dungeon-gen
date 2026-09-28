extends RefCounted
class_name GridUtils
## Funciones puras para trabajar con posiciones en espacio de voxels.
## No dependen de ninguna instancia, por eso son estáticas.

## Convierte una coordenada de voxel (int) a posición mundial (float), centrada en la celda.
static func grid_to_world(grid_pos: Vector3i, voxel_scale: Vector3) -> Vector3:
	return Vector3(grid_pos) * voxel_scale
