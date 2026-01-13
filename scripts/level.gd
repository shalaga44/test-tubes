extends RefCounted
class_name Level

var _tubes: Array = []: set = set_tubes
var _tubes_reset_copy: Array = []
var _drains_reset_copy: Array = []

enum WIN_CONDITIONS {GATHER_ALL, GATHER_ONE}
const WIN_CONDITIONS_HINTS := [
	"Gather all colors, each in it's own container, to win",
	"Gather %s color in any one container to win"
]
var win_condition: int = 0
# only for win_condition = 1
var win_color: int = 0

var _performance_ratings: Array = [] # array of up to 3 Dictionaries (index stars-1)

var completion_table: Array = []
var description: String = ""


func set_drains(drains: Array) -> bool:
	if _tubes.is_empty():
		print_debug("Tubes array wasn't set, can't set drains")
		return false
	if drains.size() != _tubes.size():
		print_debug("Drains array doesn't equal to tubes array")
		return false

	for i in drains.size():
		if !(typeof(drains[i]) == TYPE_FLOAT or typeof(drains[i]) == TYPE_INT):
			print_debug("Invalid type of drain array member: ", typeof(drains[i]))
			return false

		var drain_val: int = int(drains[i]) # accept 2.0, 1.0 etc.
		if drain_val in Tube.DRAINS.values():
			get_tube(i).drains = drain_val
		else:
			print_debug("Drains array member' value is invalid: ", drains[i])
			return false

	return true


# new_rating = {"stars": 1..3, "moves": 1..50, "vol": 0..400 (optional)}
func add_rating(new_rating: Dictionary) -> bool:
	if new_rating.is_empty():
		return false

	var stars: int = int(new_rating.get("stars", 0))
	if stars < 1 or stars > 3:
		return false

	if _performance_ratings.is_empty():
		_performance_ratings.resize(3)
		_performance_ratings[stars - 1] = new_rating
	else:
		for each in _performance_ratings:
			if each == null:
				continue
			if typeof(each) == TYPE_DICTIONARY and int(each.get("stars", 0)) == stars:
				print_debug("%s-star rating is already added" % stars)
				return false
		_performance_ratings[stars - 1] = new_rating

	return true


func get_performance(moves: int = Globals.MAX_MOVES, vol: int = 0) -> int:
	var rating: int = 0
	if _performance_ratings.is_empty():
		return -1

	for each in _performance_ratings:
		if each == null:
			continue
		if typeof(each) != TYPE_DICTIONARY:
			continue

		var each_moves: int = int(each.get("moves", Globals.MAX_MOVES))
		var each_vol: int = int(each.get("vol", Globals.MAX_TUBE_VOLUME * Globals.MAX_MOVES))
		var each_stars: int = int(each.get("stars", 0))

		if moves <= each_moves and vol <= each_vol:
			rating = each_stars

	return rating


func set_tubes(input_tubes: Array) -> bool:
	_tubes.clear()

	if !check_input_tubes(input_tubes):
		print_debug("Level initialization failed")
		return false

	for t in input_tubes:
		var tube := Tube.new()
		tube.set_volume(t.size())
		if !tube.set_content(t):
			print_debug("Error setting tube content: ", t)
			_tubes.clear()
			return false
		_tubes.append(tube)

	build_completion_table()
	return true


func get_all_tubes_content() -> Array:
	var all_tubes_content: Array = []
	for each in _tubes:
		all_tubes_content.append(each.get_content())
	return all_tubes_content


func get_tubes_number() -> int:
	return _tubes.size()


func get_tube(tube_num: int) -> Tube:
	return _tubes[tube_num]


func check_input_tubes(tubes_2_check: Array) -> bool:
	if typeof(tubes_2_check) != TYPE_ARRAY or tubes_2_check.is_empty():
		return false

	for i in tubes_2_check.size():
		if typeof(tubes_2_check[i]) != TYPE_ARRAY or tubes_2_check[i].is_empty():
			print_debug("Tube data is of wrong type or empty")
			return false
		if tubes_2_check[i].size() < 1 or tubes_2_check[i].size() > Globals.MAX_TUBE_VOLUME:
			print_debug("Invalid size of TUBE #", i)
			return false
		for j in tubes_2_check[i].size():
			var v = tubes_2_check[i][j]
			if !(typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT):
				print_debug("Invalid color type in TUBE #", i)
				return false
			var c: int = int(v)
			if c < 0 or c > Globals.MAX_COLORS:
				print_debug("Invalid color %s in TUBE #%s" % [c, i])
				return false

	return true


# number of portions for every color
func build_completion_table() -> void:
	completion_table.resize(Globals.MAX_COLORS)
	for i in completion_table.size():
		completion_table[i] = 0

	for each in _tubes:
		var tube: Array = each.get_content()
		for j in tube.size():
			if tube[j] > 0:
				completion_table[tube[j] - 1] += 1


# for GATHER_ALL and GATHER_ONE
func check_win_condition() -> bool:
	if win_condition == WIN_CONDITIONS.GATHER_ALL:
		var full_color: int = 0
		for each_tube in _tubes:
			var summ: int = 0
			var num: int = 0
			for each_part in each_tube.get_content():
				if each_part != 0:
					summ += each_part
					num += 1

			# warning-ignore:integer_division
			if num == 0 or (summ / num == each_tube.get_top_color() and completion_table[each_tube.get_top_color() - 1] == num):
				full_color += 1

		return full_color == _tubes.size()

	elif win_condition == WIN_CONDITIONS.GATHER_ONE:
		var wrong_tube: bool = false
		for each_tube in _tubes:
			if !wrong_tube and each_tube.get_top_color() == win_color:
				var num: int = 0
				for each_part in each_tube.get_content():
					if each_part == 0:
						continue
					if each_part == win_color:
						num += 1
					else:
						wrong_tube = true
						break

				if !wrong_tube and num == completion_table[win_color - 1]:
					return true
		return false

	print_debug("You shouldn't be there")
	return false


# input argument is a Dictionary
func import_level(data) -> bool:
	var MAX_DESC_SIZE: int = 160

	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		print_debug("Wrong data type or empty")
		return false

	if !data.has("tubes") or typeof(data.tubes) != TYPE_ARRAY or data.tubes.is_empty():
		print_debug("No 'tubes' property or invalid type")
		return false

	if data.tubes.size() > Globals.MAX_TUBES:
		print_debug("More then %s tubes is not allowed in level, found %s tubes" % [Globals.MAX_TUBES, data.tubes.size()])
		return false

	for i in data.tubes.size():
		if typeof(data.tubes[i]) != TYPE_ARRAY or data.tubes[i].is_empty():
			print_debug("Tube data is of wrong type or empty")
			return false
		if data.tubes[i].size() < 1 or data.tubes[i].size() > Globals.MAX_TUBE_VOLUME:
			print_debug("Tube #%s has invalid size of %s" % [i, data.tubes[i].size()])
			return false
		for each in data.tubes[i]:
			if !(typeof(each) == TYPE_FLOAT or typeof(each) == TYPE_INT):
				print_debug("Tube #%s has value of invalid type: %s" % [i, typeof(each)])
				return false
			var c: int = int(each)
			if c < 0 or c > Globals.MAX_COLORS:
				print_debug("Tube #%s has invalid color value %s" % [i, each])
				return false

	if data.has("drains"):
		if typeof(data.drains) != TYPE_ARRAY:
			print_debug("'drains' property is of invalid type")
			return false
		if data.drains.size() != data.tubes.size():
			print_debug("'drains' property size must equal tubes size")
			return false
		for each in data.drains:
			if !(typeof(each) == TYPE_FLOAT or typeof(each) == TYPE_INT):
				print_debug("'drains' has value of invalid type: ", typeof(each))
				return false
			var dv: int = int(each)
			if dv < 0 or dv > 2:
				print_debug("'drains' has invalid value of ", each)
				return false

	if data.has("desc"):
		if typeof(data.desc) != TYPE_STRING:
			print_debug("'desc' property is of invalid type")
			return false
		if data.desc.length() > MAX_DESC_SIZE:
			print_debug("'desc' will be truncated to %s symbols" % MAX_DESC_SIZE)
			data.desc = data.desc.substr(0, MAX_DESC_SIZE)

	if data.has("win_color"):
		if !(typeof(data.win_color) == TYPE_FLOAT or typeof(data.win_color) == TYPE_INT):
			print_debug("'win_color' property is of invalid type")
			return false
		var wc: int = int(data.win_color)
		if wc < 0 or wc > Globals.MAX_COLORS:
			print_debug("'win_color' value is invalid")
			return false

		var win_color_present: bool = false
		for i in data.tubes.size():
			for each in data.tubes[i]:
				if int(each) == wc:
					win_color_present = true
		if wc != 0 and !win_color_present:
			print_debug("'win_color' value was not found in tubes")
			return false

	if data.has("ratings"):
		if typeof(data.ratings) != TYPE_ARRAY:
			print_debug("'ratings' property is of invalid type")
			return false
		if data.ratings.size() > 3:
			print_debug("'ratings' property can have no more than 3 records")
			return false

		if !data.ratings.is_empty():
			for each in data.ratings:
				if typeof(each) != TYPE_DICTIONARY:
					print_debug("A record has an invalid type")
					return false
				if !each.has("stars") or !each.has("moves"):
					print_debug("A record should have 'stars' and 'moves' properties")
					return false
				if !(typeof(each.stars) == TYPE_FLOAT or typeof(each.stars) == TYPE_INT) or !(typeof(each.moves) == TYPE_FLOAT or typeof(each.moves) == TYPE_INT):
					print_debug("A record's 'stars' or 'moves' property has invalid type")
					return false

				var stars_val: int = int(each.stars)
				var moves_val: int = int(each.moves)

				if stars_val < 1 or stars_val > 3:
					print_debug("A record's 'stars' property is invalid: ", each.stars)
					return false
				if moves_val < 1:
					print_debug("A record's 'moves' property is invalid: ", each.moves)
					return false
				if moves_val > Globals.MAX_MOVES:
					print_debug("A record's 'moves' property is invalid: %s, setting to max" % each.moves)
					each.moves = Globals.MAX_MOVES

				if each.has("vol"):
					if !(typeof(each.vol) == TYPE_FLOAT or typeof(each.vol) == TYPE_INT):
						print_debug("A record's 'vol' property has invalid type - setting to 0")
						each.vol = 0
					var vol_val: int = int(each.vol)
					if vol_val < 0:
						print_debug("A record's 'vol' property is too small: %s, setting to 0" % each.vol)
						each.vol = 0
					if vol_val > Globals.MAX_TUBE_VOLUME * Globals.MAX_MOVES:
						print_debug("A record's 'vol' property is too big: %s, setting to max" % each.vol)
						each.vol = Globals.MAX_TUBE_VOLUME * Globals.MAX_MOVES

	if !set_tubes(data.tubes):
		print_debug("Error while setting tubes, import aborted")
		return false

	if data.has("drains") and !set_drains(data.drains):
		print_debug("Error while setting drains, import aborted")
		return false

	if data.has("desc"):
		description = data.desc

	if data.has("win_color"):
		var wc2: int = int(data.win_color)
		if wc2 != 0:
			win_condition = WIN_CONDITIONS.GATHER_ONE
		else:
			win_condition = WIN_CONDITIONS.GATHER_ALL
		win_color = wc2

	if data.has("ratings"):
		for each in data.ratings:
			if !add_rating(each):
				print_debug("Error while adding rating")

	make_reset_copy()
	return true


# generate classic water pour puzzle level:
# all tubes are of the same volume
# each color has the same volume randomly portioned and poured in all tubes
# except two which are empty
# so the number of colors is equal to number of tubes minus two
func make_random_classic_level(colors: int, volume: int) -> bool:
	var MIN_COLORS := 3
	var MIN_VOLUME := 2

	if colors < MIN_COLORS:
		print_debug("Wrong 'colors' number, setting to MIN")
		colors = MIN_COLORS
	if colors > Globals.MAX_COLORS or colors > Globals.MAX_TUBES - 2:
		print_debug("Wrong 'colors' number, setting to MAX")
		colors = min(Globals.MAX_COLORS, Globals.MAX_TUBES - 2)

	if volume < MIN_VOLUME:
		print_debug("Wrong 'volume', setting to MIN")
		volume = MIN_VOLUME
	if volume > Globals.MAX_TUBE_VOLUME:
		print_debug("Wrong 'volume', setting to MAX")
		volume = Globals.MAX_TUBE_VOLUME

	# make empty tubes
	var tube: Array
	var tubes: Array = []
	for i in colors + 2:
		tube = []
		tube.resize(volume)
		tube.fill(0)
		tubes.append(tube)

	# make random palette
	var palette: Array = []
	for i in Globals.MAX_COLORS + 1:
		if i == 0:
			continue
		palette.append(i)

	randomize()
	palette.shuffle()
	palette.resize(colors)

	var portions: Array = []
	portions.resize(colors)
	portions.fill(volume)

	# fill tubes with colors from palette
	var iterations := colors * volume
	var tube_por: int
	var tube_num: int
	var random_color_index: int
	for i in iterations:
		tube_por = i % volume
		tube_num = int((i - tube_por) / volume)

		random_color_index = randi() % palette.size()
		portions[random_color_index] -= 1
		tubes[tube_num][tube_por] = palette[random_color_index]
		if portions[random_color_index] == 0:
			palette.remove_at(random_color_index)
			portions.remove_at(random_color_index)

	# init level
	if !set_tubes(tubes):
		print_debug("Error while setting random tubes, classic level generation aborted")
		return false

	make_reset_copy()
	return true


# generate classic water pour puzzle level where every tube has faucets
func make_random_classic_faucet_level(colors: int, volume: int) -> bool:
	if make_random_classic_level(colors, volume):
		var drains: Array = []
		drains.resize(get_tubes_number())
		drains.fill(2)

		# set two tubes to '1', but not last two empty tubes
		var t1: int = randi() % (drains.size() - 3)
		drains[t1] = 1
		var t2: int = randi() % (drains.size() - 3)
		if t2 == t1:
			if t2 % 2 == 0 and t2 > 0:
				t2 -= 1
			else:
				t2 += 1
		drains[t2] = 1

		if set_drains(drains):
			return true

		print_debug("Error while setting drains for random classic faucet level")
		return false

	return false


func make_reset_copy() -> void:
	if _tubes.is_empty():
		print_debug("The tubes array is empty!")
		return

	if !_tubes_reset_copy.is_empty():
		print_debug("The reset copy was already made!")
	else:
		for i in _tubes.size():
			_tubes_reset_copy.append(get_tube(i).get_content().duplicate())

	if !_drains_reset_copy.is_empty():
		print_debug("Drains reset copy was already made!")
	else:
		for i in _tubes.size():
			_drains_reset_copy.append(get_tube(i).drains)


func reset_level() -> void:
	if _tubes_reset_copy.is_empty():
		print_debug("Reset copy is empty!")
		return
	if _drains_reset_copy.is_empty():
		print_debug("Drains reset copy is empty!")
		return

	_tubes.clear()
	if !set_tubes(_tubes_reset_copy):
		print_debug("Wrong tube data in reset copy")
	if !set_drains(_drains_reset_copy):
		print_debug("Wrong drains data in reset copy")
