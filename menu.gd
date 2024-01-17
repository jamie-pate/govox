extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	call_deferred('_on_Showcase_pressed')


func _on_Showcase_pressed():
	get_parent().add_child(load('res://showcase.tscn').instance())
	hide()


func _on_Benchmark_pressed():
	get_parent().add_child(load('res://main.tscn').instance())
	hide()
