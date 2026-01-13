extends MarginContainer

signal clicked(node_num)

var label_text: String = ""
var menu # pointer to Menu scene


func _ready():
	$RTLabel.bbcode_enabled = true
	$RTLabel.text = label_text
	clicked.connect(Callable(menu, "_on_label_clicked"))


func _on_RTLabel_gui_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		var parts := String(get_name()).split("_")
		var idx := int(parts[parts.size() - 1])
		emit_signal("clicked", idx)


func _on_RTLabel_mouse_entered():
	$RTLabel.text = "[color=yellow]%s[/color]" % label_text


func _on_RTLabel_mouse_exited():
	$RTLabel.text = label_text
