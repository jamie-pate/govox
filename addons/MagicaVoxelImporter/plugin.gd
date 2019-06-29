tool
extends EditorPlugin

const VoxelImport = preload('./voxel-import.gd')
var import_plugin
var control

func _enter_tree():
	#Add import plugin
	import_plugin = ImportPlugin.new()
	add_import_plugin(import_plugin)

func _exit_tree():
	#remove plugin
	remove_import_plugin(import_plugin)
	import_plugin = null


##############################################
#                Import Plugin               #
##############################################


class ImportPlugin extends EditorImportPlugin:
	#The Name shown in the Plugin Menu
	func get_importer_name():
		return 'MagicaVoxel-Importer'

	#The Name shown under 'Import As' in the Import menu
	func get_visible_name():
		return "MagicaVoxels as Points"

	#The File extensions that this Plugin can import. Those will then show up in the Filesystem
	func get_recognized_extensions():
		return ['vox']

	#The Resource Type it creates. Im still not sure what exactly this does
	func get_resource_type():
		return "Mesh"

	#The extenison the imported file will have
	func get_save_extension():
		return 'mesh'

	#Returns an Array or Dictionaries that declare which options exist.
	#Those options will show up under 'Import As'
	func get_import_options(preset):
		var options = [
			{'name': 'bone_map', 'default_value': ''},
			{'name': 'smoothing', 'default_value': 1.0,
				'property_hint': PROPERTY_HINT_RANGE, 'hint_string': '0.0,10.0,0.1'}
		]
		#options.append( { "name":"Pack in scene", "default_value":false } )
		#options.append( { "name":"target_path", "default_value":"" } )
		return options

	#The Number of presets
	func get_preset_count():
		return 0

	#The Name of the preset.
	func get_preset_name(preset):
		return "Default"


	func import( source_path, save_path, options, platforms, gen_files ):
		var old_mesh: ArrayMesh
		var file: File = File.new()
		if file.file_exists(save_path) and false:
			old_mesh = ResourceLoader.load(save_path)
		var vi = VoxelImport.new()
		var mesh: ArrayMesh = vi.load_vox(source_path, options, platforms, gen_files, old_mesh)

		var full_path = "%s.%s" % [save_path, get_save_extension()]
		return ResourceSaver.save(full_path, mesh)
