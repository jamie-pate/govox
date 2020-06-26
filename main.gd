extends Spatial

const VoxelImport = preload('res://addons/MagicaVoxelImporter/voxel-import.gd')

# class member variables go here, for example:
# var a = 2
# var b = "textvar"

var files = {}

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	var fd = $FileDialog
	if fd:
		var container: Node = get_container()
		container.get_node('Scale').edit_value = $Model.transform.basis.get_scale().z
		container.get_node('PointSize').edit_value = $Model.point_size
		container.get_node('Zoom').edit_value = $Position3D/Camera.transform.origin.z

func _process(delta):
	# Called every frame. Delta is time since last frame.
	# Update game logic here.
	$Label.text = '%s' % Engine.get_frames_per_second()

func get_container():
	 return $Control/Panel/Grid

func _on_Scale_value_changed(value):
	 $Model.transform = Transform().scaled(Vector3(value, value, value))


func _on_PointSize_value_changed(value):
	$Model.point_size = value

func _on_Zoom_value_changed(value):
	$Position3D/Camera.transform.origin = Vector3(0, 0, value)


func _on_CheckBox_toggled(button_pressed):
	$Characters.visible = button_pressed


func _on_CheckButton_toggled(button_pressed):
	# don't use proper fullscreen because its harder for recording
	OS.window_borderless = button_pressed
	OS.window_maximized = button_pressed
	$Button2.visible = button_pressed


func _on_Button2_pressed():
	get_tree().quit()


func _on_CheckButton2_toggled(button_pressed):
	$AnimationPlayer.playback_active = button_pressed


func _on_FileDialog_file_load(index, path):
	files[index] = path
	$Model.mesh = yield(load_vox(path), 'completed')

func load_vox(path: String):
	var container = get_container()
	var smoothing_edit = container.get_node('NormalSmoothing')
	var smoothing = smoothing_edit.edit_value
	var vi = VoxelImport.new()
	$Loading.visible = true
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	var mesh = vi.load_vox(path, {bone_map='', smoothing=smoothing})
	set_show_normals(get_container().get_node('NormalDebug').edit_value, mesh)
	$Loading.visible = false
	yield(get_tree(), 'idle_frame')
	return mesh


func _on_Enable_toggled(button_pressed):
	var container = get_container()
	var edit = container.get_node('NormalDebug/Edit')
	var nd = container.get_node('NormalDebug')
	edit.visible = button_pressed
	nd.edit_value = 1 if button_pressed else 0


func _on_Button_pressed():
	var vi = VoxelImport.new()
	for index in files:
		if index == 0:
			$Model.mesh = yield(load_vox(files[index]), 'completed')


func _on_Edit_value_changed(value):
	if $Model:
		set_show_normals(value, $Model.mesh)

func set_show_normals(value, mesh):
	if mesh:
		var mat = mesh.surface_get_material(0)
		mat.set_shader_param('show_normals', value)
