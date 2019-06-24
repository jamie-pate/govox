extends FileDialog

const VoxelImport = preload('res://addons/MagicaVoxelImporter/voxel-import.gd')

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var meshInstance: MeshInstance

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Button_pressed():
	show()


func _on_FileDialog_files_selected(paths):
	for p in paths:
		pass


func _on_FileDialog_file_selected(path):
	var vi = VoxelImport.new()
	meshInstance.mesh = vi.load_vox(path)
