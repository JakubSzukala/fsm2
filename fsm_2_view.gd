@tool
class_name FSM2View
extends Control

var RADIUS = 50

var _transitions_view: Array
var _nodes_view: Dictionary

var _curve: Curve


func visualize(nodes_view: Dictionary, transitions_view: Array) -> void:
	_nodes_view = nodes_view
	_transitions_view = transitions_view
	_adjust()
	queue_redraw()


func _adjust() -> void:
	for node_name in _nodes_view.keys():
		# Initial placement of nodes
		var seed = abs(node_name.hash())
		var coords = Vector2(seed % int(size.x), seed % int(size.y))
		_nodes_view[node_name] = coords

	var steps = 100
	_curve = _initialize_temperature_curve(steps, 0.001 * size.x, 0.1 * size.x)
	for i in range(steps):
		_optimize(i)


func _optimize(step: int) -> void:
	var displacement_accumulator: Dictionary = {}
	for node_name in _nodes_view.keys():
		displacement_accumulator[node_name] = Vector2.ZERO
	var area = size.x * size.y
	var nodes_count = _nodes_view.size()
	var k = sqrt(area/nodes_count)
	_repulse_pass(displacement_accumulator, k)
	_attract_pass(displacement_accumulator, k)
	_center_pass(displacement_accumulator, k)
	_temperature_pass(displacement_accumulator, step)
	for node_name in displacement_accumulator.keys():
		_nodes_view[node_name] += displacement_accumulator[node_name]
		_nodes_view[node_name] = Vector2(
			clamp(_nodes_view[node_name].x, 0.0, size.x),
			clamp(_nodes_view[node_name].y, 0.0, size.y)
		)


func _initialize_temperature_curve(steps: int, min_temp: float, max_temp: float) -> Curve:
	var curve = Curve.new()
	curve.bake_resolution = steps
	curve.max_value = max_temp#0.1 * size.x # Highest upper step boundary
	curve.min_value = min_temp#0.001 * size.x # Lowest upper step boundary
	curve.min_domain = 0
	curve.max_domain = steps
	curve.add_point(Vector2(curve.max_domain * 0.25, curve.max_value))
	curve.add_point(Vector2(curve.max_domain * 0.5, curve.max_value * 0.3))
	curve.add_point(Vector2(curve.max_domain, 0.0))
	curve.bake()
	return curve


func _repulse_pass(displacement_accumulator: Dictionary, k: float) -> void:
	for node_1_name in _nodes_view.keys():
		for node_2_name in _nodes_view.keys():
			if node_1_name != node_2_name:
				var node_1_pos: Vector2 = _nodes_view[node_1_name]
				var node_2_pos: Vector2 = _nodes_view[node_2_name]
				var direction: Vector2 = -node_1_pos.direction_to(node_2_pos)
				var distance: float = node_1_pos.distance_to(node_2_pos)
				var magnitude: float = _repulse_magnitude(k, distance)
				displacement_accumulator[node_1_name] += direction * magnitude


func _attract_pass(displacement_accumulator: Dictionary, k: float) -> void:
	for transition in _transitions_view:
		var node_1_name: String = transition["from"]
		var node_1_pos: Vector2 = _nodes_view[node_1_name]
		var node_2_name: String = transition["to"]
		var node_2_pos: Vector2 = _nodes_view[node_2_name]
		var distance: float = node_1_pos.distance_to(node_2_pos)
		var magnitude = _attract_magnitude(k, distance)
		displacement_accumulator[node_1_name] += node_1_pos.direction_to(node_2_pos) * magnitude
		displacement_accumulator[node_2_name] += node_2_pos.direction_to(node_1_pos) * magnitude


func _center_pass(displacement_accumulator: Dictionary, k: float) -> void:
	for node_name in _nodes_view.keys():
		var node_pos = _nodes_view[node_name]
		var center = size / 2.0
		var direction = node_pos.direction_to(center)
		var distance = node_pos.distance_to(center)
		var magnitude = _attract_magnitude(k, distance)
		displacement_accumulator[node_name] += magnitude * direction


func _temperature_pass(displacement_accumulator: Dictionary, step: int) -> void:
	for node_name in displacement_accumulator.keys():
		var value: Vector2 = displacement_accumulator[node_name]
		var temperature = _curve.sample_baked(step)
		print(temperature)
		displacement_accumulator[node_name] = value.limit_length(temperature)


func _repulse_magnitude(k: float, d: float) -> float:
	return pow(k, 2) / d


func _attract_magnitude(k: float, d: float) -> float:
	return pow(d, 2) / k


func _draw() -> void:
	for transition in _transitions_view:
		var from_pos: Vector2 = _nodes_view[transition["from"]]
		var to_pos: Vector2 = _nodes_view[transition["to"]]
		from_pos = from_pos.move_toward(to_pos, RADIUS)
		to_pos = to_pos.move_toward(from_pos, RADIUS)
		_draw_transition(from_pos, to_pos, transition["on"])

	for node in _nodes_view.keys():
		_draw_node(node, _nodes_view[node])


func _draw_node(node_name: String, node_position: Vector2) -> void:
	var settings: = EditorInterface.get_editor_settings()
	var node_edge_color = settings["interface/theme/accent_color"].darkened(0.3)
	var node_root_color = settings["interface/theme/base_color"]
	draw_circle(node_position, RADIUS, node_root_color, true, -1.0, true)
	draw_circle(node_position, RADIUS, node_edge_color, false, 2, true)
	draw_string(ThemeDB.fallback_font, node_position - Vector2(RADIUS, 0),
			node_name, HORIZONTAL_ALIGNMENT_CENTER, -1)


func _draw_transition(from_pos: Vector2, to_pos: Vector2, on: String) -> void:
	# Get matching colors from editor settings
	var settings: = EditorInterface.get_editor_settings()
	var transition_color: Color = settings["interface/theme/accent_color"]

	# Draw an arrow
	var ARROW_EDGE_LEN = 30
	var ARROW_WIDTH = 3.0
	draw_line(from_pos, to_pos, transition_color, ARROW_WIDTH, true)
	var marker: Vector2 = to_pos.direction_to(from_pos)
	var arrow_edge_end_1 = marker.rotated(-PI/8) * ARROW_EDGE_LEN + to_pos
	var arrow_edge_end_2 = marker.rotated(PI/8) * ARROW_EDGE_LEN + to_pos
	draw_line(to_pos, arrow_edge_end_1, transition_color, ARROW_WIDTH, true)
	draw_line(to_pos, arrow_edge_end_2, transition_color, ARROW_WIDTH, true)

	# Draw input subscript, to draw rotated text we need to set transform
	var MAGIC_RHS_OFFSET = 60
	var TEXT_FROM_ARROW_OFFSET = -10
	var draw_angle = from_pos.direction_to(to_pos).angle()
	var from_pos_offset = 10
	if draw_angle > PI/2.0 or draw_angle < -PI/2.0:
		# Transform should be corrected by PI if we end up drawing upside down
		# after flip we also have to change offset so node won't cover subscript
		draw_angle -= PI
		from_pos_offset = -on.length() - MAGIC_RHS_OFFSET
	draw_set_transform(from_pos, draw_angle)
	draw_string(ThemeDB.fallback_font, Vector2(from_pos_offset,
			TEXT_FROM_ARROW_OFFSET), on, HORIZONTAL_ALIGNMENT_LEFT)
	draw_set_transform(Vector2.ZERO, 0)
