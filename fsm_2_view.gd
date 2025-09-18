@tool
class_name FSM2View
extends Control

var default_font : Font = ThemeDB.fallback_font;
var _view: Dictionary
var _steps: = 3

func InnerView() -> Dictionary:
	return {}


func InnerView_add_node(
		view: Dictionary,
		node_name: String,
		node_position: Vector2,
		node_transitions: Array
	) -> void:
	view[node_name] = {
		"position" : node_position,
		"transitions" : node_transitions
	}


func InnerView_get_node_position(view: Dictionary, node_name: String) -> Vector2:
	return view[node_name]["position"]


func InnerView_get_node_transitions(view: Dictionary, node_name: String) -> Array:
	return view[node_name]["transitions"]


func InnerView_set_node_position(view: Dictionary, node_name: String, node_position: Vector2) -> void:
	view[node_name]["position"] = node_position


func visualize(view: Dictionary) -> void:
	_view = InnerView()
	for node: String in view.keys():
		InnerView_add_node(_view, node, Vector2(0, 0), view[node])
	_adjust()
	queue_redraw()


func _adjust() -> void:
	for node_name in _view.keys():
		# Initial placement of nodes
		var seed = abs(node_name.hash())
		var coords = Vector2(seed % int(size.x), seed % int(size.y))
		InnerView_set_node_position(_view, node_name, coords)

	for i in range(20):
		# Run given amount of adjustment cycles
		_placement_pass(250.0)


func _placement_pass(spring_len: float) -> void:
	var force_accumulator: Dictionary = {}
	_spring_pass(spring_len, force_accumulator)

	var mass = 1.0
	var dt = 1.0
	for node_name in force_accumulator.keys():
		var resultant_force: Vector2 = force_accumulator[node_name]
		var acceleration: Vector2 = resultant_force / mass
		var shift: Vector2 = 0.5 * acceleration * dt * dt
		var current_pos: Vector2 = InnerView_get_node_position(_view, node_name)
		InnerView_set_node_position(_view, node_name, current_pos + shift)


func _spring_pass(spring_len: float, force_accumulator: Dictionary) -> void:
	var spring_constant = 1.0
	for from_node_name in _view.keys():
		for transition in InnerView_get_node_transitions(_view, from_node_name):
			var from_pos: Vector2 = InnerView_get_node_position(_view, from_node_name)
			var to_node_name = transition["to"]
			var to_pos: Vector2 = InnerView_get_node_position(_view, to_node_name)

			var root_pos: Vector2 = (from_pos + to_pos) / 2.0
			var stable_len: float = spring_len / 2.0 # Single side
			if not force_accumulator.has(from_node_name):
				force_accumulator[from_node_name] = Vector2.ZERO
			force_accumulator[from_node_name] += _spring_force(
				root_pos,
				stable_len,
				spring_constant,
				from_pos
			)
			if not force_accumulator.has(to_node_name):
				force_accumulator[to_node_name] = Vector2.ZERO
			force_accumulator[to_node_name] += _spring_force(
				root_pos,
				stable_len,
				spring_constant,
				to_pos
			)


func _spring_force(
		root_pos: Vector2,
		base_spring_len: float,
		spring_constant,
		pos: Vector2
	) -> Vector2:
	var current_spring_len = root_pos.distance_to(pos)
	var displacement = current_spring_len - base_spring_len
	return -spring_constant * displacement * root_pos.direction_to(pos)


func _draw() -> void:
	for node in _view.keys():
		# Draw transitions first so they are beneath nodes
		for transition in InnerView_get_node_transitions(_view, node):
			var from_pos: Vector2 = InnerView_get_node_position(_view, node)
			var to_pos: Vector2 = InnerView_get_node_position(_view, transition["to"])
			_draw_transition(from_pos, to_pos)

	for node in _view.keys():
		# Now we can draw nodes above transitions
		_draw_node(node, _view[node]["position"])


func _draw_node(node_name: String, node_position: Vector2) -> void:
	var radius = 50
	draw_circle(node_position, radius, Color.SEA_GREEN, true, -1.0, true)
	draw_string(default_font, node_position - Vector2(radius, 0), node_name,
			HORIZONTAL_ALIGNMENT_CENTER, 2 * radius, 14)


func _draw_transition(from_pos: Vector2, to_pos: Vector2) -> void:
	draw_line(from_pos, to_pos, Color.DARK_GREEN, 5.0, true)
