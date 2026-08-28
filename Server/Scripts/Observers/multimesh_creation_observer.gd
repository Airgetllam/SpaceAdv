extends Observer
class_name MultimeshCreationObserver

var blocks_map: Dictionary = {}
var cell_size: int = ServerConfig.CELL_SIZE
var hp_colors: Dictionary = ServerConfig.HP_COLORS

func query() -> QueryBuilder:
	return q.with_all([C_Modules]).on_added()


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var modules: C_Modules = entity.get_component(C_Modules)
	var blocks_data = []
	var all_blocks = []
	blocks_map = {}
	for i in modules.list:
		blocks_data.append(i['blocks_data'])
	for i in blocks_data:
		for j in i:
			all_blocks.append(j)
	for block in all_blocks:
		block["local_pos"] = Vector2(block["local_pos"])
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	for block in all_blocks:
		var pos = block["local_pos"]
		if pos.x < min_x: min_x = pos.x
		if pos.x > max_x: max_x = pos.x
		if pos.y < min_y: min_y = pos.y
		if pos.y > max_y: max_y = pos.y
	var center = Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0) + Vector2(0.5, 0.5)
	for block in all_blocks:
		block["local_pos"] -= center
	var multimesh_component = C_Multimesh.new()
	var groups = _group_blocks_by_id(all_blocks)
	for i in groups:
		var mesh_inst = _create_multimesh(groups[i], str(i), modules.available_blocks, modules.blocks_textures)
		multimesh_component.multlimesh[mesh_inst.name] = mesh_inst
	multimesh_component.blocks_map = blocks_map
	multimesh_component.all_blocks = all_blocks
	cmd.add_component(entity, multimesh_component)
	print('[MultimeshCreationObserver] C_Multimesh был добавлен к сущности с ID ', entity.id)


func _group_blocks_by_id(blocks: Array) -> Dictionary:
	var result = {}
	for block in blocks:
		var id = block["block_id"]
		var pos = block["local_pos"]
		if not result.has(id):
			result[id] = []
		result[id].append(pos)
	return result


func _create_multimesh(blocks: Array, texture: String, available_blocks: Array[BlockDefinition], blocks_textures: Dictionary) -> MultiMeshInstance2D:
	var ship_mesh = MultiMeshInstance2D.new()
	var multimesh = MultiMesh.new()
	ship_mesh.name = str(texture)
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = blocks.size()

	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	
	var vertices = PackedVector2Array([
		Vector2(0, 0), Vector2(cell_size, 0),
		Vector2(0, cell_size), Vector2(cell_size, 0),
		Vector2(cell_size, cell_size), Vector2(0, cell_size)
	])
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	
	var uvs = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0),
		Vector2(0, 1), Vector2(1, 0),
		Vector2(1, 1), Vector2(0, 1)
	])
	arrays[ArrayMesh.ARRAY_TEX_UV] = uvs
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	multimesh.mesh = mesh
	for i in range(blocks.size()):
		var pos = blocks[i]
		var _transform = Transform2D()
		var block_hp = 0
		var block_energy = 0
		var block_thrust = 0
		var block_mass = 0
		# Позиция ячейки в мировых координатах (сдвиг на CELL_SIZE уже учтён размером вершин)
		_transform.origin = Vector2(pos.x * cell_size, pos.y * cell_size)
		multimesh.set_instance_transform_2d(i, _transform)
		multimesh.set_instance_color(i, hp_colors[100])
		for block in available_blocks:
			if block.id == texture:
				block_hp = block.get_hp()
				block_energy = block.get_energy_cost()
				block_thrust = block.get_thrust()
				block_mass = block.get_mass()
		blocks_map[blocks[i]] = {
			'block_index': i,
			'block_id': int(texture),
			'block_hp': block_hp,
			'block_hp_max': block_hp, # НЕ МЕНЯТЬ
			'energy': block_energy,
			'thrust': block_thrust,
			'block_mass': block_mass,
			'destroy': false,
			'mmi': ship_mesh}
	ship_mesh.multimesh = multimesh
	ship_mesh.texture = blocks_textures[texture]
	
	return ship_mesh

func _get_center_position(blocks: Array) -> Vector2:
	var center := Vector2.ZERO
	for block in blocks:
		center += block["local_pos"]
	return center / blocks.size()
