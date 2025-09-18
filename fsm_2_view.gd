@tool
class_name FSM2View
extends Control

var default_font : Font = ThemeDB.fallback_font;
var _transitions_view
var _nodes_view: Dictionary
var _steps: = 3
var _edge_spring_constant = 1.0
var _centering_spring_constant = 0.7
var _neighbour_spring_constant = 0.00000

@export var curve: Curve


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

	var steps = 20
	curve.clear_points()
	curve.bake_resolution = steps
	curve.max_value = 0.1 * size.x # Highest upper step boundary
	curve.min_value = 0.001 * size.x # Lowest upper step boundary
	curve.min_domain = 0
	curve.max_domain = steps
	curve.add_point(Vector2(curve.max_domain * 0.25, curve.max_value))
	curve.add_point(Vector2(curve.max_domain * 0.5, curve.max_value * 0.3))
	curve.add_point(Vector2(curve.max_domain, 0.0))
	curve.bake()
	for i in range(steps):
		_placement_pass(i)


func _placement_pass(step: int) -> void:
	var displacement_accumulator: Dictionary = {}
	for node_name in _nodes_view.keys():
		displacement_accumulator[node_name] = Vector2.ZERO
	var area = size.x * size.y
	var nodes_count = _nodes_view.size()
	var c = 1
	var k = c * sqrt(area/nodes_count)
	_repulse_pass(displacement_accumulator, k)
	_attract_pass(displacement_accumulator, k)
	_temperature_pass(displacement_accumulator, step)
	for node_name in displacement_accumulator.keys():
		_nodes_view[node_name] += displacement_accumulator[node_name]
		_nodes_view[node_name] = Vector2(
			clamp(_nodes_view[node_name].x, 0.0, size.x),
			clamp(_nodes_view[node_name].y, 0.0, size.y)
		)
		print(_nodes_view[node_name], size)


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


func _temperature_pass(displacement_accumulator: Dictionary, step: int) -> void:
	for node_name in displacement_accumulator.keys():
		var value: Vector2 = displacement_accumulator[node_name]
		var temperature = curve.sample_baked(step)
		displacement_accumulator[node_name] = value.limit_length(temperature)


func _repulse_magnitude(k: float, d: float) -> float:
	return pow(k, 2) / d


func _attract_magnitude(k: float, d: float) -> float:
	return pow(d, 2) / k


func _draw() -> void:
	# Draw transitions first so they are beneath nodes
	for transition in _transitions_view:
		var from_pos: Vector2 = _nodes_view[transition["from"]]
		var to_pos: Vector2 = _nodes_view[transition["to"]]
		_draw_transition(from_pos, to_pos)

	for node in _nodes_view.keys():
		# Now we can draw nodes above transitions
		_draw_node(node, _nodes_view[node])


func _draw_node(node_name: String, node_position: Vector2) -> void:
	var radius = 50
	var settings: = EditorInterface.get_editor_settings()
	var node_edge_color = settings["interface/theme/accent_color"].darkened(0.3)
	var node_root_color = settings["interface/theme/base_color"]
	draw_circle(node_position, radius, node_root_color, true, -1.0, true)
	draw_circle(node_position, radius, node_edge_color, false, 2, true)
	draw_string(default_font, node_position - Vector2(radius, 0), node_name,
			HORIZONTAL_ALIGNMENT_CENTER, 2 * radius, 14)


func _draw_transition(from_pos: Vector2, to_pos: Vector2) -> void:
	var settings: = EditorInterface.get_editor_settings()
	var transition_color: Color = settings["interface/theme/accent_color"]
	draw_line(from_pos, to_pos, transition_color, 3.0, true)
