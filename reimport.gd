tool
extends SceneTree

func _init():
    call_deferred('doit')

func doit():
    print('INIT')
    var c = root.get_node('EditorNode').get_children()
    var fs
    for n in c:
        if n is EditorFileSystem:
            fs = n

    # not sure if this does anything
    var r = fs.update_file('res://c1_rigged.vox')

    call_deferred('quit')
    print(r)
