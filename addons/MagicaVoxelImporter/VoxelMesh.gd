tool
extends MeshInstance

export(float) var waist setget _set_waist
export(float) var displacement_ratio setget _set_displacement
export(bool) var sitting setget _set_sit


func _get_mats() -> Array:
	var result = []
	var mat = mesh.surface_get_material(0) if mesh && mesh.get_surface_count() else null
	if mat:
		result.append(mat)
	mat = get_surface_material(0) if get_surface_material_count() else null
	if mat:
		result.append(mat)
	mat = material_override
	if mat:
		result.append(mat)
	return result


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
