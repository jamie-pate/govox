extends Spatial

const SETTINGS_FILE = "user://settings.json"
const PERSIST_NODES = [
	'ImageSizeX',
	'ImageSizeY',
	'CaptureCount',
	'EncodeVideo',
	'Model'
]

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
		container.get_node('Zoom').edit_value = $'%Position3D/Camera'.transform.origin.z

	if get_node_or_null('MultiMeshinstance'):
		_on_BenchmarkButton_toggled(false)
	_load_settings()


func _on_Control_changed():
	_save_settings()


func _load_settings():
	var f := File.new()
	var err := f.open(SETTINGS_FILE, File.READ)
	if err == ERR_FILE_NOT_FOUND:
		return
	assert(err == OK, 'Unable to load %s for reading: %s' % [SETTINGS_FILE, err])
	var json := JSON.parse(f.get_as_text())
	f.close()
	assert(json.error == OK, 'Unable to parse %s: %s (%s on line %s)' % [SETTINGS_FILE, json.error, json.error_string, json.error_line])
	for name in PERSIST_NODES:
		if name in json.result:
			var n = get_node_or_null('%%%s' % [name])
			if !n:
				printerr('unable to find node to load setting: %s' % [name])
			else:
				if 'value' in n:
					n.value = json.result[name]
				if 'pressed' in n:
					n.pressed = json.result[name]
	if 'files' in json.result:
		files = json.result.files
		reload_vox()

func _save_settings():
	var settings := {}
	for name in PERSIST_NODES:
		var n = get_node_or_null('%%%s' % [name])
		if !n:
			printerr('unable to find node to save settings: %s' % [name])
		else:
			if 'value' in n:
				settings[name] = n.value
			if 'pressed' in n:
				settings[name] = n.pressed
	settings.files = files
	var f := File.new()
	var err := f.open(SETTINGS_FILE, File.WRITE)
	assert(err == OK, 'Unable to open %s for writing: %s' % [SETTINGS_FILE, err])
	f.store_string(JSON.print(settings))
	f.close()


func _process(delta):
	# Called every frame. Delta is time since last frame.
	# Update game logic here.
	var vpsz := get_tree().root.size
	var verts = Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME)
	var meshes = Performance.get_monitor(Performance.RENDER_OBJECTS_IN_FRAME)
	if get_node_or_null('MultiMeshInstance'):
		var multimesh = ' (%sx multimesh)' % [$MultiMeshInstance.multimesh.instance_count] if $MultiMeshInstance.visible else ''
		$Bench/Label.text = '%s fps %s verts %sx%s (~%s voxels %s mesh%s%s)' % [
			Engine.get_frames_per_second(),
			verts,
			vpsz.x,
			vpsz.y,
			round(verts * 0.5),
			meshes,
			'es' if meshes != 1 else '',
			multimesh
		]

func get_container():
	 return $Control/Panel/Grid

func _on_Scale_value_changed(value):
	 $Model.transform = Transform().scaled(Vector3(value, value, value))


func _on_PointSize_value_changed(value):
	$Model.point_size = value

func _on_Zoom_value_changed(value):
	$'%Position3D/Camera'.transform.origin = Vector3(0, 0, value)


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
	_save_settings()

func load_vox(path: String):
	var container = get_container()
	var smoothing_edit = container.get_node('NormalSmoothing') if container else null
	var smoothing = smoothing_edit.edit_value if smoothing_edit else 1.0
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
	reload_vox()

func _on_Background_pressed():
	$BgFileDialog.show_modal()

func _on_BgFileDialog_file_load(index, path):
	var tex = ImageTexture.new()
	tex.load(path)
	$'%Background'.texture = tex

func reload_vox():
	for index in files:
		if int(index) == 0:
			$Model.mesh = yield(load_vox(files[index]), 'completed')

func _on_Edit_value_changed(value):
	if $Model:
		set_show_normals(value, $Model.mesh)

func set_show_normals(value, mesh):
	if mesh:
		var mat = mesh.surface_get_material(0)
		mat.set_shader_param('show_normals', value)

func _on_BenchmarkButton_toggled(button_pressed):
	if !get_node_or_null('MultiMeshInstance'):
		return
	OS.vsync_enabled = false
	var mm := $MultiMeshInstance.multimesh as MultiMesh
	$BenchmarkPos/Camera.current = button_pressed && !$Bench/Camera2CheckButton.pressed
	$BenchmarkPos/Camera2.current = button_pressed && $Bench/Camera2CheckButton.pressed
	$BenchmarkPos/Light.visible = button_pressed
	$'%Position3D/Camera'.current = !button_pressed
	for c in get_children():
		if c is Spatial:
			c.visible = !button_pressed
	$BenchmarkPos.visible = true
	$MultiMeshInstance.visible = button_pressed
	for c in $Bench.get_children():
		c.visible = button_pressed || c in [$Bench/BenchmarkButton, $Bench/Label, $Bench/Spacer]
	var spacing = 2.0 if $Bench/FarSpacingCheckButton.pressed else 0.5
	if button_pressed:
		# probably best if this is a power of 2
		var count := 64
		var side = ceil(sqrt(count))
		mm.instance_count = side * side
		var tfm = $MeshInstance4.global_transform
		$AnimationPlayer.seek(0.0, true)
		$AnimationPlayer2.seek(0.0, true)
		yield(get_tree(), 'idle_frame')
		yield(get_tree(), 'idle_frame')
		$AnimationPlayer.stop()
		$AnimationPlayer2.stop()
		for x in range(side):
			for y in range(side):
				var i = x + (side * y)
				var itfm = Transform().translated(spacing * Vector3(x - side * 0.5, 0, y - side * 0.5)) * tfm
				mm.set_instance_transform(i, itfm)
	else:
		mm.instance_count = 0
		$AnimationPlayer.play()
		$AnimationPlayer2.play()


func _on_FastCheckButton_toggled(button_pressed):
	var mat: ShaderMaterial = $MultiMeshInstance.multimesh.mesh.surface_get_material(0)
	mat.set_shader_param('fast', button_pressed)


func _on_Camera2CheckButton_toggled(button_pressed):
	$BenchmarkPos/Camera.current = !button_pressed
	$BenchmarkPos/Camera2.current = button_pressed



func _on_FarSpacingCheckButton_toggled(button_pressed):
	_on_BenchmarkButton_toggled(true)


func _on_LODBiasSlider_value_changed(value):
	var mat: ShaderMaterial = $MultiMeshInstance.multimesh.mesh.surface_get_material(0)
	mat.set_shader_param('lod_bias', value)
	$Bench/LODBias.text = 'LOD Bias %s' % [value]


func _on_SaveFileDialog_file_load(index, path):
	var cb := $'%CaptureProgressBar' as ProgressBar
	var cc := $'%CaptureCount' as SpinBox
	var ap := $AnimationPlayer as AnimationPlayer
	var p := $'%Position3D'
	var vp := $'%Viewport' as Viewport
	var size := vp.size
	vp.size = Vector2($'%ImageSizeX'.value, $'%ImageSizeY'.value)
	var file_template := $SaveFileDialog.current_path as String
	var file_base := file_template.get_basename().trim_suffix('0000')
	var file_ext := file_template.get_extension()
	if !file_ext:
		file_ext = 'png'
	ap.playback_active = false
	var tex := ImageTexture.new()
	cb.visible = true
	cb.value = 0
	cb.max_value = cc.value
	for i in cc.value:
		p.rotation_degrees.y = 360 * (float(i) / float(cc.value))
		var filename := '%s%04d.%s' % [file_base, i, file_ext]
		yield(VisualServer, 'frame_post_draw')
		var data := vp.get_texture().get_data()
		data.flip_y()
		data.save_png(filename)
		cb.value = i
	ap.playback_active = true
	vp.size = size
	if $'%EncodeVideo'.pressed:
		cb.value = cb.max_value
		var cmd := 'ffmpeg'
		var args := PoolStringArray([
			'-framerate', '30',
			'-pattern_type', 'sequence', '-i', '%s%%04d.%s' % [file_base,  file_ext],
			'-c:v', 'libvpx-vp9',
			'-pix_fmt', 'yuv420p',
			'-b:v', '1M',
			'-y',
			'%s.webm' % [file_base]
		])
		var args_str := args.join(' ')
		print('%s %s:' % [cmd, args_str])
		var output = []
		var result := OS.execute(cmd, args, true, output, true, true)
		if !result == OK:
			printerr('Error: %s exited with %s' % [cmd, result])
		print(output)
	cb.visible = false


func _on_CloseButton_pressed():
	for n in get_tree().get_nodes_in_group('Menu'):
		n.visible = true
	queue_free()
