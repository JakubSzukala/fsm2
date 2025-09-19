@tool
class_name FSM2View
extends HBoxContainer

## Control node definig draw space for graph
@onready var graph_space: Control = $GraphSpace

## Editable coefficients used while optimizing graph
var radius: float
var margin: float
var c_coeff: float

## Graph representation
var _transitions_view: Array
var _nodes_view: Dictionary

## Request to redraw
var _scheduled_draw: bool = false

## Set a graph to be drawn. We expect data in format:
## nodes_view: {"statename" : Vector2.ZERO, ...}
## and transitions_view [{"from" : "fromstate", "on" : "inputname", "to" : "tostate"}, ...]
func set_graph(nodes_view: Dictionary, transitions_view: Array) -> void:
	_nodes_view = nodes_view
	_transitions_view = transitions_view
	_scheduled_draw = true


## Set optimization and view parameters, usually used when restoring saved state
func set_params(params: Dictionary) -> void:
	radius = params["radius"]
	c_coeff = params["c_coeff"]
	$VBoxContainer/HBoxContainer/RadiusEdit.value = radius
	$VBoxContainer/HBoxContainer2/CCoefficientEdit.value = c_coeff


## Get optimization and view parameters, usually used when saving state
func get_params() -> Dictionary:
	return {
		"radius" : $VBoxContainer/HBoxContainer/RadiusEdit.value,
		"c_coeff" : $VBoxContainer/HBoxContainer2/CCoefficientEdit.value
	}


## Verify if we are ready to draw
func _can_draw() -> bool:
	return _scheduled_draw and graph_space and graph_space.size > Vector2.ZERO and \
			_nodes_view and _transitions_view


## We do most of the work through _process, because here we continously check
## that 1) there is need to redraw 2) there are proper conditions to draw
## 3) we have anything to draw. Sometimes 2) or 3) are not fullfilled and this
## way we can delay the draw until ready
func _process(_delta: float) -> void:
	if _can_draw():
		# Fetch parameters from UI
		radius = $VBoxContainer/HBoxContainer/RadiusEdit.value
		c_coeff = $VBoxContainer/HBoxContainer2/CCoefficientEdit.value
		margin = 2 * radius

		# Redraw graph
		_refine()
		queue_redraw()
		_scheduled_draw = false


## Runs refinement process, starting from initial nodes placement and improving it
func _refine() -> void:
	# Initial placement of nodes
	for node_name in _nodes_view.keys():
		var seed = abs(node_name.hash())
		var coords = Vector2(
			seed % int(graph_space.size.x),
			seed % int(graph_space.size.y)
		)
		_nodes_view[node_name] = coords

	# Run optimization
	var steps = 100
	var curve = _initialize_temperature_curve(
		steps,
		0.001 * graph_space.size.x, 0.1 * graph_space.size.x)
	var k = _initialize_k()
	for i in range(steps):
		_optimization_pass(i, k, curve)


## Single adjustment of nodes positions, using given parameters
func _optimization_pass(step: int, k: float, temperature_curve: Curve) -> void:
	# Accumulate displacement from each pass
	var displacement_accumulator: Dictionary = {}
	for node_name in _nodes_view.keys():
		displacement_accumulator[node_name] = Vector2.ZERO

	# Run each pass and accumulate displacement
	_repulse_pass(displacement_accumulator, k)
	_attract_pass(displacement_accumulator, k)
	_center_pass(displacement_accumulator, k)
	_temperature_pass(displacement_accumulator, step, temperature_curve)

	# Once we are done we can apply displacement, clamping final positions so
	# these fit into draw window
	for node_name in displacement_accumulator.keys():
		_nodes_view[node_name] += displacement_accumulator[node_name]
		_nodes_view[node_name] = Vector2(
			clamp(
				_nodes_view[node_name].x,
				graph_space.position.x + margin,
				graph_space.position.x + graph_space.size.x - margin
			),
			clamp(
				_nodes_view[node_name].y,
				graph_space.position.y + margin,
				graph_space.position.y + graph_space.size.y - margin
			)
		)


## Initialize curve used to sample temperature during temperature pass, this is
## used to limit max displacement, curve has initially high values then rapidly
## decreases to then stay close to zero at the end. Large changes when we are
## far from optimum (hopefully jump over local minima to find better ones) and
## small changes for refined final movement.
func _initialize_temperature_curve(steps: int, min_temp: float, max_temp: float) -> Curve:
	var curve = Curve.new()
	curve.bake_resolution = steps
	curve.max_value = max_temp
	curve.min_value = min_temp
	curve.min_domain = 0
	curve.max_domain = steps
	curve.add_point(Vector2(curve.max_domain * 0.25, curve.max_value))
	curve.add_point(Vector2(curve.max_domain * 0.5, curve.max_value * 0.3))
	curve.add_point(Vector2(curve.max_domain, 0.0))
	curve.bake()
	return curve


## Factor dictating attracting and repulsing forces. Based on draw area and nodes
## count.
func _initialize_k() -> float:
	var area = graph_space.size.x * graph_space.size.y
	var nodes_count = _nodes_view.size()
	return c_coeff * sqrt(area/nodes_count)


## Repulse nodes from each other.
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


## Attract nodes connected with edges.
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


## Attract all nodes to the center of drawing area.
func _center_pass(displacement_accumulator: Dictionary, k: float) -> void:
	for node_name in _nodes_view.keys():
		var node_pos = _nodes_view[node_name]
		var center = graph_space.position + graph_space.size / 2.0
		var direction = node_pos.direction_to(center)
		var distance = node_pos.distance_to(center)
		var magnitude = _attract_magnitude(k, distance)
		displacement_accumulator[node_name] += magnitude * direction


## Limit final displacements to temperature
func _temperature_pass(displacement_accumulator: Dictionary, step: int, temperature_curve: Curve) -> void:
	for node_name in displacement_accumulator.keys():
		var value: Vector2 = displacement_accumulator[node_name]
		var temperature = temperature_curve.sample_baked(step)
		displacement_accumulator[node_name] = value.limit_length(temperature)


## Calculate repulse magnitude based on 1991 algorithm from Fruchterman and Reingol
func _repulse_magnitude(k: float, d: float) -> float:
	return pow(k, 2) / d


## Calculate attract magnitude based on 1991 algorithm from Fruchterman and Reingol
func _attract_magnitude(k: float, d: float) -> float:
	return pow(d, 2) / k


## Draw graph
func _draw() -> void:
	# Draw nodes
	for node in _nodes_view.keys():
		_draw_node(node, _nodes_view[node])

	# Draw transitions
	for transition in _transitions_view:
		var from_pos: Vector2 = _nodes_view[transition["from"]]
		var to_pos: Vector2 = _nodes_view[transition["to"]]
		from_pos = from_pos.move_toward(to_pos, radius)
		to_pos = to_pos.move_toward(from_pos, radius)
		_draw_transition(from_pos, to_pos, transition["on"])


## Draw node at position.
func _draw_node(node_name: String, node_position: Vector2) -> void:
	var settings: = EditorInterface.get_editor_settings()
	var node_edge_color = settings["interface/theme/accent_color"].darkened(0.3)
	var node_root_color = settings["interface/theme/base_color"]
	draw_circle(node_position, radius, node_root_color, true, -1.0, true)
	draw_circle(node_position, radius, node_edge_color, false, 2, true)
	draw_string(ThemeDB.fallback_font, node_position - Vector2(radius, 0),
			node_name, HORIZONTAL_ALIGNMENT_CENTER, -1)


## Draw transition between two positions with given subscript.
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
	var MAGIC_RHS_FACTOR = 10.0
	var TEXT_FROM_ARROW_OFFSET = -10
	var draw_angle = from_pos.direction_to(to_pos).angle()
	var from_pos_offset = 40
	if draw_angle > PI/2.0 or draw_angle < -PI/2.0:
		# Transform should be corrected by PI if we end up drawing upside down
		# after flip we also have to change offset so node won't cover subscript
		draw_angle -= PI
		from_pos_offset = -on.length() * 10
	draw_set_transform(from_pos, draw_angle)
	draw_string(ThemeDB.fallback_font, Vector2(from_pos_offset,
			TEXT_FROM_ARROW_OFFSET), on, HORIZONTAL_ALIGNMENT_LEFT)
	draw_set_transform(Vector2.ZERO, 0)


## Every time draw window is resized, we should redraw the graph
func _on_resized() -> void:
	_scheduled_draw = true


func _on_graph_redraw_button_pressed() -> void:
	_scheduled_draw = true
