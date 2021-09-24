tool
extends MeshInstance

# class member variables go here, for example:
# var a = 2
# var b = "textvar"
export(float) var point_size setget _set_point_size
export(float) var waist setget _set_waist
export(float) var displacement_ratio setget _set_displacement
export(bool) var sitting setget _set_sit
var _lastmesh

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	get_tree().connect('screen_resized', self, '_resized')
	if point_size == 0:
		point_size = 24
	_resized()

func _get_mats():
	var result = []
	var mat = mesh.surface_get_material(0)
	if mat:
		result.append(mat)
	mat = get_surface_material(0)
	if mat:
		result.append(mat)
	mat = material_override
	if mat:
		result.append(mat)
	return result

func _process(delta):
	if _lastmesh != mesh:
		_lastmesh = mesh
		call_deferred('_resized')
		call_deferred('_set_point_size_deferred', point_size)

func _resized():
	if mesh:
		var viewport = get_viewport()
		if viewport:
			var screen_size = viewport.get_size_override() if viewport.is_size_override_enabled() else viewport.size
			for mat in _get_mats():
				mat.set_shader_param('screen_size', screen_size)
			if mesh:
				_set_point_size_deferred(point_size)


func _set_point_size(value):
	point_size = value
	call_deferred('_set_point_size_deferred', value)
	call_deferred('_resized')

func _set_point_size_deferred(value):
	if mesh:
		for mat in _get_mats():
			mat.set_shader_param('point_size', value)

func _set_waist(value):
	waist = value
	if mesh:
		for mat in _get_mats():
			mat.set_shader_param('waist', value)

func _set_displacement(value):
	displacement_ratio = value
	if mesh:
		for mat in _get_mats():
			mat.set_shader_param('displacement_ratio', value)

func _set_sit(value):
	sitting = value
	if mesh:
		for mat in _get_mats():
			mat.set_shader_param("sitting",value)
