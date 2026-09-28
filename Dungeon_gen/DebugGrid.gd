extends MeshInstance3D
class_name DungeonDebugGrid
## Dibuja las líneas de la grilla del dungeon (un borde por cada celda, en
## cada piso) para verificar visualmente que las salas, pasillos y escaleras
## caen exactamente donde deberían según la lógica del generador.

func rebuild(dungeon_size: Vector3i, voxel_scale: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(Color(0, 0, 0, 1))

	for floor_i in range(dungeon_size.y + 1):
		var y := floor_i * voxel_scale.y
		for x in range(dungeon_size.x + 1):
			st.add_vertex(Vector3(x * voxel_scale.x, y, 0))
			st.add_vertex(Vector3(x * voxel_scale.x, y, dungeon_size.z * voxel_scale.z))
		for z in range(dungeon_size.z + 1):
			st.add_vertex(Vector3(0, y, z * voxel_scale.z))
			st.add_vertex(Vector3(dungeon_size.x * voxel_scale.x, y, z * voxel_scale.z))

	mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	material_override = mat
