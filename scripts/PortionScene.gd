extends ColorRect

# Accepts either an int (palette index/marker) or a Color directly.
func set_portion_color(new_color) -> void:
	if typeof(new_color) == TYPE_COLOR:
		color = new_color
		return

	if typeof(new_color) != TYPE_INT:
		print_debug("Invalid color value type: ", typeof(new_color))
		return

	var c: int = int(new_color)
	if c == 0:
		color = Globals.EMPTY_COLOR
	elif c == -1:
		color = Globals.NO_COLOR
	elif c > 0 and c <= Globals.MAX_COLORS:
		color = Globals.VALERIA_palette[c - 1]
	else:
		print_debug("Invalid color value: ", c)
