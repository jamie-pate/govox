extends HBoxContainer

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var edit_value = 0.0 setget _set_value, _get_value

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

var _count = 0
func _set_value(v: float):
	edit_value = v
	if $Edit:
		$Edit.value = v
	else:
		_count += 1
		assert(_count < 10)
		call_deferred('_set_value', v)

func _get_value():
	if $Edit:
		return $Edit.value
	else:
		return edit_value
