tool
extends Spatial

signal _physics_collide_bones()

# todo: plugin menu?
# in the meantime you can check 'Collect Bones' to manually run the tool script
export var collect_bones := false setget _set_collect_bones
export var auto_reimport := true
export var mesh_path: NodePath = 'MeshInstance' setget _set_mesh_path
export var skeleton_path: NodePath setget _set_skeleton_path
export var area_path: NodePath = 'Area' setget _set_area_path


func _ready():
	set_physics_process(false)


func _set_collect_bones(value):
	collect_bones = true
	_collect_bones()
	collect_bones = false

func _set_mesh_path(value: NodePath):
	mesh_path = value
	_collect_bones()

func _set_skeleton_path(value: NodePath):
	skeleton_path = value
	_collect_bones()

func _set_area_path(value: NodePath):
	area_path = value
	_collect_bones()

func _collect_bones():
	var skel := get_node_or_null(skeleton_path) as Skeleton
	var mi := get_node_or_null(mesh_path) as MeshInstance
	var area := get_node_or_null(area_path) as Area
	if !mi || !skel:
		if is_inside_tree():
			if mesh_path && !mi:
				printerr('Mesh not found at path %s' % [mesh_path])
			if skeleton_path && !skel:
				printerr('Skeleton not found at path %s' % [skeleton_path])
			if area_path && !area:
				printerr('Area not found at path %s' % [area_path])
		return
	var mesh := mi.mesh as ArrayMesh
	if !mesh:
		printerr('Mesh %s is not an arraymesh' % [mesh])
		return
	if !mesh.resource_path:
		printerr('Mesh %s has no resource path' % [mesh])
		return
	if mesh.get_surface_count() < 1:
		printerr('Mesh %s has no surface' % [mesh])
		return
	# TODO: support additional surfaces?

	# ensure no skeleton for rigging
	var mesh_skel := mi.skeleton
	mi.skeleton = NodePath()
	var s := 0
	var surface := mesh.surface_get_arrays(s)
	var vertices := surface[ArrayMesh.ARRAY_VERTEX] as PoolVector3Array
	var bones = surface[ArrayMesh.ARRAY_BONES]
	if !bones is PoolIntArray:
		if bones is PoolRealArray:
			print('bones is PoolRealArray')
		elif !bones:
			bones = PoolIntArray()
		else:
			printerr('bones is %s' % typeof(bones))
	var weights : PoolRealArray = surface[ArrayMesh.ARRAY_WEIGHTS] if surface[ArrayMesh.ARRAY_WEIGHTS] else PoolRealArray()

	print('verts: %s bones: %s weights: %s ' %  [len(vertices), len(bones), len(weights)])
	var vert_count = len(vertices)
	var import_file = '%s.import' % mesh.resource_path
	var f := File.new()
	var d := Directory.new()
	if !d.file_exists(import_file):
		printerr('Import file does not exist: %s' % [import_file])
		return
	var err := f.open(import_file, File.READ)
	if err != OK:
		printerr('Unable to read from import file %s: %s' % [import_file, err])
		return

	bones.resize(vert_count * ArrayMesh.ARRAY_WEIGHTS_SIZE)
	weights.resize(vert_count * ArrayMesh.ARRAY_WEIGHTS_SIZE)

	var space := PhysicsServer.area_get_space(area.get_rid())
	var state := PhysicsServer.space_get_direct_state(space)
	var USE_BOX = false
	var voxel = PhysicsServer.shape_create(PhysicsServer.SHAPE_BOX if USE_BOX else PhysicsServer.SHAPE_SPHERE)

	var root_scale := 1.0
	var mat := mesh.surface_get_material(0) as ShaderMaterial
	if mat:
		root_scale = mat.get_shader_param('root_scale')
	var data = mi.scale * 0.5 * root_scale
	if USE_BOX:
		PhysicsServer.shape_set_data(voxel, data)
	else:
		PhysicsServer.shape_set_data(voxel, data.x)
	var qp := PhysicsShapeQueryParameters.new()

	qp.shape_rid = voxel
	qp.collide_with_areas = true
	qp.collide_with_bodies = false
	var missing_voxels := []
	var bone_map = {}

	var w := PoolRealArray()
	for i in ArrayMesh.ARRAY_WEIGHTS_SIZE:
		w.append(0.0)
	var enabled_shapes := []
	for c in area.get_children():
		if c is CollisionShape && !c.disabled:
			enabled_shapes.append(c)
	for i in len(vertices):
		var v := vertices[i]

		qp.transform = mi.global_transform * Transform.translated(v)
		var c := state.intersect_shape(qp, ArrayMesh.ARRAY_WEIGHTS_SIZE)
		var weight_total := 0.0
		var c_len = len(c)
		if !c_len:
			missing_voxels.append(qp.transform.origin)

		var bone_count := 0
		var b_i = ArrayMesh.ARRAY_WEIGHTS_SIZE * i
		for b in ArrayMesh.ARRAY_WEIGHTS_SIZE:
			w[b] = 0.0
			var found := false
			if b < c_len && b_i + b < vert_count * ArrayMesh.ARRAY_WEIGHTS_SIZE:
				var shape_idx := c[b].shape as int
				var collider = c[b].collider
				if collider != area:
					printerr('Collided %s with something else? %s' % [
						qp.transform.origin,
						collider
					])
				else:
					var shape = area.shape_owner_get_owner(area.shape_find_owner(shape_idx))
					if c_len == 1:
						w[b] = 1.0
					else:
						var RAY_LEN = 10000.0
						var exclude := []
						for es in enabled_shapes:
							es.disabled = es != shape
						var ray_end = shape.global_transform.origin
						# ray points toward the center of the shape from the current voxel
						var ray = ray_end - qp.transform.origin
						var ray_start = ray_end - ray.normalized() * RAY_LEN
						var intersect = state.intersect_ray(ray_start, ray_end, exclude, ~0, false, true)
						for es in enabled_shapes:
							es.disabled = false
						if intersect:
							for e in exclude:
								print(e.get_id())
							var ishape = area.shape_owner_get_owner(area.shape_find_owner(intersect.shape))
							assert(ishape == shape)
							w[b] = intersect.position.distance_to(qp.transform.origin)
						else:
							printerr("intersection didn't work with %s %s > %s" % [shape.name, ray_start, ray_end])

					weight_total += w[b]
					var bone_name = shape.name
					if !bone_name in bone_map:
						bone_map[bone_name] = 0
					bone_map[bone_name] += 1
					var bone := skel.find_bone(bone_name)
					found = true
					bone_count += 1
					bones[b_i + b] = bone
					# TODO: distribute weights?
			if !found:
				bones[b_i + b] = 0
		for b in ArrayMesh.ARRAY_WEIGHTS_SIZE:
			var bw = w[b] / weight_total if weight_total > 0 else 0.0
			weights[b_i + b] = bw

	PhysicsServer.free_rid(voxel)
	var bone_ids = {}
	for bone in bone_map:
		bone_ids[bone] = skel.find_bone(bone)
	print('bones: %s\n%s' % [bone_map, bone_ids])
	if len(missing_voxels) == len(vertices):
		printerr('No collisions found!')
		return
	if missing_voxels:
		printerr('no collision for %s voxels at %s...!' % [
			len(missing_voxels),
			missing_voxels.slice(0, 10)
		])

	var lines := PoolStringArray()
	while !f.eof_reached():
		var line := f.get_line()
		if !line.begins_with('bones=') && !line.begins_with('weights='):
			lines.append(line)
	f.close()
	if len(lines) && lines[len(lines) - 1] == '':
		lines.remove(len(lines) - 1)
	err = f.open(import_file, File.WRITE)
	if err != OK:
		printerr('Unable to write to import file %s: %s' % [import_file, err])
		return
	for l in lines:
		f.store_line(l)
	f.store_line('bones=%s' % [var2str(bones)])
	f.store_line('weights=%s' % [var2str(weights)])
	f.close()


	print('Saved to %s bones: %s weights: %s' % [
		import_file,
		len(bones),
		len(weights)
	])
	if mesh_skel:
		mi.skeleton = mesh_skel
	# big hack...
	if collect_bones && auto_reimport:
		call_deferred('re_import')

func re_import():
	if Engine.editor_hint:
		var mi := get_node_or_null(mesh_path) as MeshInstance
		if !mi:
			return
		var mesh := mi.mesh as ArrayMesh
		if !mesh:
			return
		var bc: Control
		for c in get_tree().root.get_node('EditorNode').get_children():
			if c is EditorInterface:
				c.edit_resource(mesh)
				c.inspect_object(self)
				bc = c.get_base_control()
				break
		if bc:
			# super duper big hack
			var import = bc.find_node('Import', true, false)
			if import:
				import._reimport()
