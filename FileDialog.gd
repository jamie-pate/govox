extends FileDialog

signal file_load(index, path)

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
	emit_signal('file_load', 0, path)
