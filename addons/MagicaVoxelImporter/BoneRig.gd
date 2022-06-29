tool
extends Spatial

signal _physics_collide_bones()

# todo: plugin menu?
# in the meantime you can check 'Collect Bones' to manually run the tool script
export var collect_bones := false setget _set_collect_bones
export var mirror_ltr := false setget _set_mirror_ltr
export var mirror_rtl := false setget _set_mirror_rtl
export var auto_reimport := true

# magic property that will update the prefix on ALL rig children!
export var bone_prefix: String setget _set_bone_prefix

# These 3 are exported below using _get_property_list
var mesh_path: NodePath setget _set_mesh_path
var skeleton_path: NodePath setget _set_skeleton_path
var area_path: NodePath setget _set_area_path

export var blend_factor: float = 1.0

var _new_prefix = null
var _old_prefix = null

func _ready():
	set_physics_process(false)


func _get_property_list():
	# apparently this isn't exposed?
	#PropertyHint.PROPERTY_HINT_NODE_PATH_VALID_TYPES
	var PROPERTY_HINT_NODE_PATH_VALID_TYPES = PROPERTY_HINT_IMAGE_COMPRESS_LOSSLESS + 13
	return [
		{
			name='skeleton_path',
			type=TYPE_NODE_PATH,
			hint=PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string='Skeleton'
		},
		{
			name='mesh_path',
			type=TYPE_NODE_PATH,
			hint=PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string='MeshInstance'
		},
		{
			name='area_path',
			type=TYPE_NODE_PATH,
			hint=PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string='Area'
		}
	]

func _set_collect_bones(value):
	collect_bones = true
	if value:
		_collect_bones()
	collect_bones = false

func _set_mirror_ltr(value):
	mirror_ltr = value
	if value:
		_mirror_shapes('Left', 'Right')
	mirror_ltr = false

func _set_mirror_rtl(value):
	mirror_rtl = value
	if value:
		_mirror_shapes('Right', 'Left')
	mirror_rtl = false

func _mirror_shapes(from: String, to: String):
	for c in get_children():
		if c is CollisionShape && c.name.find(from) > -1:
			var mirror_name = c.name.replace(from, to)
			var other = get_node_or_null(mirror_name)
			if other:
				other.transform.origin = c.transform.origin * Vector3(-1, 1, 1)
				other.transform.basis = c.transform.basis.rotated(Vector3.UP, deg2rad(180))

func _set_bone_prefix(value):
	if value == bone_prefix:
		return
	_new_prefix = value
	# debounce because this will remove focus from the inspector..
	var first_run = _old_prefix == null
	if !first_run:
		yield(get_tree().create_timer(1.0), 'timeout')
	if is_instance_valid(self) && is_inside_tree() && _new_prefix == value:
		# this is the initial load
		_old_prefix = bone_prefix
		bone_prefix = value
		if !first_run:
			print('replacing bone prefix %s > %s' % [_old_prefix, bone_prefix])
			for c in get_children():
				if c.name.begins_with(_old_prefix):
					c.name = bone_prefix + c.name.trim_prefix(_old_prefix)

func _set_mesh_path(value: NodePath):
	mesh_path = value
	_collect_bones()

func _set_skeleton_path(value: NodePath):
	skeleton_path = value
	_collect_bones()

func _set_area_path(value: NodePath):
	area_path = value
	_collect_bones()


func _shape_name_to_bone_name(value: String):
	var parts = value.rsplit('#', 1)
	return parts[0] if len(parts) else ''

func _collect_bones():
	var start := OS.get_ticks_msec()
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
	var bone_overlap = {}

	var w := PoolRealArray()
	for i in ArrayMesh.ARRAY_WEIGHTS_SIZE:
		w.append(0.0)
	var enabled_shapes := {}
	for c in area.get_children():
		if c is CollisionShape && !c.disabled:
			var bone_name = _shape_name_to_bone_name(c.name)
			if !bone_name in enabled_shapes:
				enabled_shapes[bone_name] = []
			enabled_shapes[bone_name].append(c)
	assert(area.collision_mask == 0)
	var fail := []
	area.collision_layer = 1
	for i in len(vertices):
		var v := vertices[i]

		qp.transform = mi.global_transform * Transform.translated(v)
		var c := state.intersect_shape(qp, ArrayMesh.ARRAY_WEIGHTS_SIZE)
		var weight_total := 0.0
		var c_len = len(c)
		if !c_len:
			missing_voxels.append(qp.transform.origin)

		var bone_count := 0
		var bone_names := []
		var b_i = ArrayMesh.ARRAY_WEIGHTS_SIZE * i
		var b := 0
		while b < ArrayMesh.ARRAY_WEIGHTS_SIZE:
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
					var bone_name = _shape_name_to_bone_name(shape.name)
					# multiple shapes should only capture a voxel once
					if bone_name in bone_names:
						c.erase(c[b])
						c_len = len(c)
						print('double bone collision %s' % [bone_name])
						continue
					if c_len == 1:
						w[b] = 1.0
					else:
						var weight = _calc_bone_weight(area, enabled_shapes, shape, state, qp.transform.origin)
						if weight:
							w[b] = weight
					weight_total += w[b]
					if !bone_name in bone_map:
						bone_map[bone_name] = 0
					bone_names.append(bone_name)
					bone_map[bone_name] += 1
					var bone := skel.find_bone(bone_name)
					if bone == -1:
						fail.append('Unable to find bone %s' % [bone_name])
						printerr()
					found = true
					bone_count += 1
					bones[b_i + b] = bone
					# TODO: distribute weights?
			if !found:
				bones[b_i + b] = 0
			b += 1
		b = 0
		while b < ArrayMesh.ARRAY_WEIGHTS_SIZE:
			var bw = w[b] / weight_total if weight_total > 0 else 0.0
			if blend_factor != 1.0:
				bw = max(0.0, min(1.0, (bw - 0.5) * blend_factor + 0.5))
			weights[b_i + b] = bw
			b += 1
		if len(bone_names) > 1:
			bone_names.sort()
			if !bone_names in bone_overlap:
				bone_overlap[bone_names] = 0
			bone_overlap[bone_names] += 1

	area.collision_layer = 0
	PhysicsServer.free_rid(voxel)
	if fail:
		printerr('Fatal error: %s' % [PoolStringArray(fail.slice(0, 10)).join('\n')])
		return
	var bone_ids = {}
	for bone in bone_map:
		bone_ids[bone] = skel.find_bone(bone)
	print('\noverlap:\n%s\n\nbones:\n%s\n\nids:\n%s\n' % [bone_overlap, bone_map, bone_ids])
	if len(missing_voxels) == len(vertices):
		printerr('No collisions found!')
		return
	if missing_voxels:
		printerr('##### WARNING #####\nNo collision for %s voxels at %s...!' % [
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
	print('Bone Collection took %sms' % [OS.get_ticks_msec() - start])
	# big hack...
	if collect_bones && auto_reimport:
		call_deferred('re_import')


func _calc_bone_weight(area: Area, enabled_shapes: Dictionary, shape: CollisionShape, state: PhysicsDirectSpaceState, origin: Vector3) -> float:
	"""
	Get the unnormalized bone weight for a bone based on the distance to the edge of the shape
	Currently measures the distance from the origin to the outside of the shape
	along a the vector between the origin and the shape's origin
	This method of smoothing requires a lot of extra volume in the shapes to blend
	on the correct axis...

	TODO: calculate the ray for each shape pair that overlaps for this voxel
	and sum the distances along that ray to the outside of the shape for each shape?
	"""
	var RAY_LEN = 10000.0
	var bone_name = _shape_name_to_bone_name(shape.name)
	for n in enabled_shapes:
		if n != bone_name:
			for es in enabled_shapes[n]:
				es.disabled = true
	var ray_end = shape.global_transform.origin
	# ray points toward the center of the shape from the current voxel
	var ray = ray_end - origin
	var ray_start = ray_end - ray.normalized() * RAY_LEN
	var intersect = state.intersect_ray(ray_start, ray_end, [], ~0, false, true)
	for n in enabled_shapes:
		for es in enabled_shapes[n]:
			es.disabled = false
	if intersect:
		return intersect.position.distance_to(origin)
	else:
		printerr("intersection didn't work with %s %s > %s" % [shape.name, ray_start, ray_end])
		return 0.0

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
			if c.is_class('EditorInterface'):
				c.edit_resource(mesh)
				c.inspect_object(self)
				bc = c.get_base_control()
				break
		if bc:
			# super duper big hack
			var import = bc.find_node('Import', true, false)
			if import:
				import._reimport()
