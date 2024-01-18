extends HBoxContainer

export var edit_value = 0.0 setget _set_value, _get_value
export var edit_path := NodePath('Edit')

var reset_value = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

var _count = 0
func _set_value(v: float):
	edit_value = v
	var edit = get_node_or_null(edit_path)
	if edit:
		edit.value = v
	else:
		_count += 1
		assert (_count < 10)
		call_deferred('_set_value', v)

func _get_value():
	var edit = get_node_or_null(edit_path)
	if edit:
		return edit.value
	else:
		return edit_value

func _on_ResetButton_pressed():
	_set_value(reset_value)
