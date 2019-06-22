extends Spatial

# class member variables go here, for example:
# var a = 2
# var b = "textvar"

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	var fd = $FileDialog
	if fd:
		fd.meshInstance = $Model
		var container: HBoxContainer = get_container()
		container.get_node("Scale").value = $Model.transform.basis.get_scale().z
		container.get_node("PointSize").value = $Model.point_size
		container.get_node("Zoom").value = $Position3D/Camera.transform.origin.z

func _process(delta):
	# Called every frame. Delta is time since last frame.
	# Update game logic here.
	$Label.text = '%s' % Engine.get_frames_per_second()

func get_container():
	 return $Control/Panel/HBoxContainer
	
func _on_Scale_value_changed(value):
	 $Model.transform = Transform().scaled(Vector3(value, value, value))


func _on_PointSize_value_changed(value):
	$Model.point_size = value

func _on_Zoom_value_changed(value):
	$Position3D/Camera.transform.origin = Vector3(0, 0, value)


func _on_CheckBox_toggled(button_pressed):
	$Characters.visible = button_pressed
