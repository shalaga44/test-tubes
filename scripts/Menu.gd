extends Control

const GAME_SCENE := preload("res://scenes/GameScene.tscn")
var game_scene

const LEVEL_LABEL := preload("res://scenes/LevelLabel.tscn")
var ready_levels: Array = [] # of Level
@onready var ready_levels_list: VBoxContainer = $MainHBox/MainVBox/ScrollContainer/LevelSelection

@onready var main_vbox: VBoxContainer = $MainHBox/MainVBox
@onready var title: RichTextLabel = $MainHBox/MainVBox/VBoxTitle/RTLTitle
@onready var import_text_control: TextEdit = $DialogImport/MarginCont/VBoxCont/InputText


func _ready():
	get_window().min_size = Globals.VPS_MIN
	make_ready_levels_list()
	load_import_help()
	get_tree().root.size_changed.connect(_on_root_size_changed)
	_on_root_size_changed()


func _on_root_size_changed() -> void:
	var ROOT_SIZE: Vector2 = get_tree().root.size

	main_vbox.set_custom_minimum_size(Vector2(ROOT_SIZE.x * 0.75, ROOT_SIZE.y * 0.9))

	var coeff: int = 3
	if ROOT_SIZE.y > 1000:
		coeff = 5

	# Title size
	var title_font_size: int = int(ROOT_SIZE.y / 18)
	title.add_theme_font_size_override("normal_font_size", title_font_size)
	title.size = Vector2(title.size.x, title_font_size + coeff)

	# Resize level labels font size (their child RichTextLabel)
	var labels_font_size: int = int(ROOT_SIZE.y / 30) - coeff
	for i in ready_levels_list.get_child_count():
		var item = ready_levels_list.get_child(i)
		if item != null and item.has_node("RTLabel"):
			var rt: RichTextLabel = item.get_node("RTLabel")
			rt.add_theme_font_size_override("normal_font_size", labels_font_size)

	# Dialog sizes
	$DialogImport.size = ROOT_SIZE * 0.8

	var import_font_size: int = int(ROOT_SIZE.x / 55) - coeff
	if import_font_size < 10:
		import_font_size = 10
	import_text_control.add_theme_font_size_override("font_size", import_font_size)


func close_game() -> void:
	if is_instance_valid(game_scene):
		game_scene.queue_free()
	set_visible(true)


func restart_game() -> void:
	close_game()
	run_game()


func make_ready_levels_list() -> void:
	load_levels()
	for i in ready_levels.size():
		var l := LEVEL_LABEL.instantiate()
		l.label_text = ready_levels[i].description
		l.menu = self
		l.set_name("LevelLabel_%s" % [i + 1])
		ready_levels_list.add_child(l)


func run_game() -> void:
	if is_instance_valid(Globals.get_level()):
		self.set_visible(false)
		game_scene = GAME_SCENE.instantiate()
		game_scene.init(self)
		get_tree().root.add_child(game_scene)
	else:
		print_debug("Game initialization failed")


func _on_label_clicked(label_num: int) -> void:
	Globals.set_level(ready_levels[label_num - 1])
	run_game()


func load_levels() -> void:
	if !ready_levels.is_empty():
		ready_levels.clear()

	var files_list: Array = get_ready_levels_list()
	if files_list.is_empty():
		print_debug("No level files found")
		return

	for each_file in files_list:
		var level_data: Dictionary = load_level(each_file)
		var l := Level.new()
		if l.import_level(level_data):
			ready_levels.append(l)
		else:
			print_debug("Was unable to load level '%s'" % each_file)


func load_level(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		print_debug("File '%s' was not found" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print_debug("Error while opening file: ", path)
		print_debug("Error message: ", FileAccess.get_open_error())
		return {}

	var level_str: String = file.get_as_text()
	return level_str2dic(level_str)


func _strip_bom(s: String) -> String:
	if s.length() > 0 and s.unicode_at(0) == 0xFEFF:
		return s.substr(1, s.length() - 1)
	return s


# Extracts the first {...} JSON object from any surrounding text.
# Ignores braces that appear inside JSON strings (double quotes).
# Also skips braces wrapped in single quotes like '{' / '}' that appear in the help text.
func _extract_first_json_object(s: String) -> String:
	var in_double: bool = false
	var escaped: bool = false

	var started: bool = false
	var depth: int = 0
	var start_idx: int = -1

	var n: int = s.length()
	for i in n:
		var c: int = s.unicode_at(i)

		if escaped:
			escaped = false
			continue

		# backslash escape inside JSON double-quoted strings
		if c == 92 and in_double: # '\\'
			escaped = true
			continue

		# toggle JSON strings
		if c == 34: # '\"'
			in_double = !in_double
			continue

		if in_double:
			continue

		# Skip braces wrapped in single quotes: '{' or '}'
		# This avoids matching the help text phrase: it starts with '{' and ends with '}'.
		var prev_is_sq: bool = (i > 0 and s.unicode_at(i - 1) == 39) # '\\''
		var next_is_sq: bool = (i + 1 < n and s.unicode_at(i + 1) == 39) # '\\''

		# brace counting outside JSON strings
		if c == 123: # '{'
			if prev_is_sq or next_is_sq:
				continue
			if !started:
				started = true
				start_idx = i
			depth += 1
			continue

		if c == 125 and started: # '}'
			if prev_is_sq or next_is_sq:
				continue
			depth -= 1
			if depth == 0:
				return s.substr(start_idx, i - start_idx + 1).strip_edges()

	return s.strip_edges()


# Accepts either pure JSON or any text that contains one JSON object somewhere inside.
func level_str2dic(level_str: String) -> Dictionary:
	if level_str == null:
		return {}

	var s: String = _strip_bom(String(level_str)).strip_edges()
	s = _extract_first_json_object(s)

	var json := JSON.new()
	var err: int = json.parse(s)
	if err != OK:
		# Avoid dumping megabytes of text into the debugger.
		var preview_len: int = min(300, s.length())
		var preview: String = s.substr(0, preview_len)
		print_debug("Invalid JSON data, error: ", json.get_error_message(), " in: ", preview)
		return {}

	var level_data = json.get_data()
	if typeof(level_data) != TYPE_DICTIONARY:
		print_debug("JSON data is of invalid type: ", typeof(level_data))
		return {}
	if level_data.is_empty():
		print_debug("Level data is empty")
		return {}
	return level_data


func get_ready_levels_list() -> Array:
	var LEVEL_EXT: String = "json"

	var dir := DirAccess.open(Globals.READY_LEVELS_PATH)
	if dir == null:
		print_debug("Error accessing ready levels directory: ", DirAccess.get_open_error())
		return []

	var err: int = dir.list_dir_begin()
	if err != OK:
		print_debug("Error while reading dir content: ", err)
		return []

	var file_name: String = dir.get_next()
	var files_list: Array = []
	while file_name != "":
		if file_name.get_extension() == LEVEL_EXT:
			files_list.append(Globals.READY_LEVELS_PATH + "/" + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()
	files_list.sort()
	return files_list


func _on_ButtonImport_pressed():
	$DialogImport.popup_centered()


func _on_ButtonPlay_pressed():
	var raw_text: String = import_text_control.get_text()

	# The import box contains help/examples text; parse only the JSON object.
	var level_data: Dictionary = level_str2dic(raw_text)

	var l := Level.new()
	if l.import_level(level_data):
		$DialogImport.hide()
		Globals.set_level(l)
		run_game()


func load_import_help() -> void:
	var help_text_file: String = "%s/level_help.txt" % Globals.LEVELS_PATH
	var help_examples_file: String = "%s/level_examples.txt" % Globals.LEVELS_PATH

	var help_text_str: String = ""
	if !FileAccess.file_exists(help_text_file):
		print_debug("File '%s' was not found" % help_text_file)
	else:
		var f1 := FileAccess.open(help_text_file, FileAccess.READ)
		if f1 == null:
			print_debug("Error while opening file: ", help_text_file)
			print_debug("Error message: ", FileAccess.get_open_error())
		else:
			help_text_str = f1.get_as_text()

	var help_examples_str: String = ""
	if !FileAccess.file_exists(help_examples_file):
		print_debug("File '%s' was not found" % help_examples_file)
	else:
		var f2 := FileAccess.open(help_examples_file, FileAccess.READ)
		if f2 == null:
			print_debug("Error while opening file: ", help_examples_file)
			print_debug("Error message: ", FileAccess.get_open_error())
		else:
			help_examples_str = f2.get_as_text()

	var help_help: String = """\nBEFORE PRESSING 'PLAY' DELETE EVERYTING HERE EXCEPT LEVEL JSON CODE
(it starts with '{' and ends with '}')
(if your level wasn't started check for errors in browser's console)
__________________________\n\n"""
	import_text_control.set_text(help_help + help_examples_str + help_text_str)


func _on_ButtonHelp_pressed():
	load_import_help()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if $DialogImport.is_visible():
			$DialogImport.hide()
		elif $DialogRLGSettings.is_visible():
			$DialogRLGSettings.hide()
		elif is_instance_valid(Globals.game_scene):
			close_game()


func _on_ButtonRLG_pressed():
	$DialogRLGSettings.popup_centered()


func _on_ButtonRandomLevelPlay_pressed():
	$DialogRLGSettings.hide()
	var t := Level.new()
	if t.make_random_classic_faucet_level(12, 4):
		Globals.set_level(t)
	else:
		print_debug("Was unable to make classic level with %s/%s" % [5, 3])
	run_game()
