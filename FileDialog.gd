extends FileDialog

signal file_load(index, path)

func _on_Button_pressed():
	show()
	var path = current_path
	current_path = ''
	current_path = path


func _on_FileDialog_files_selected(paths):
	for p in paths:
		pass


func _on_FileDialog_file_selected(path):
	emit_signal('file_load', 0, path)
