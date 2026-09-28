@tool
extends EditorScenePostImport
## Script de post-importación para los .fbx del pack PSX_Dungeon.
## El autor exportó cada pieza en la posición que tenía en SU escena de Blender
## (ej: Wall_01 quedaba en x=50..70, z=-60..-55), así que al instanciarlas
## aparecen lejísimos del origen. Esto las re-centra:
##   - X/Z: centradas en el origen.
##   - Y: la base de la pieza queda en Y=0.
## La escala (el pack usa módulos de 20 unidades) se ajusta aparte con
## "Root Scale" en el dock Importar.

func _post_import(scene: Node) -> Object:
	var bounds := _merged_aabb(scene, Transform3D(), true)
	if bounds.size == Vector3.ZERO:
		return scene
	var center := bounds.get_center()
	var offset := Vector3(-center.x, -bounds.position.y, -center.z)
	for child in scene.get_children():
		if child is Node3D:
			(child as Node3D).position += offset
	return scene

## AABB de todas las mallas, expresada en el espacio LOCAL de la raíz
## (sin incluir la transformación propia de la raíz).
func _merged_aabb(node: Node, xf: Transform3D, is_root: bool) -> AABB:
	var t := xf
	if node is Node3D and not is_root:
		t = xf * (node as Node3D).transform
	var result := AABB()
	var has := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result = t * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for c in node.get_children():
		var sub := _merged_aabb(c, t, false)
		if sub.size == Vector3.ZERO and sub.position == Vector3.ZERO:
			continue
		result = sub if not has else result.merge(sub)
		has = true
	return result
