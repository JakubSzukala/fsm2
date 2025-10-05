@tool
class_name FSM2Base
extends Node

var _nodes: Dictionary
var _transitions: Dictionary

var _current_state: FSM2State


func add_state_node(state: FSM2State) -> void:
	assert(not _nodes.has(state.name), "Can't overwrite existing node")
	_nodes[state.name] = state


func add_transition_edge(on: String, from: String, to: String) -> void:
	assert(_nodes.has(from) and _nodes.has(to), "Can't add edge between nonexistent nodes")
	var key = from + "/" + on
	assert(not _transitions.has(key), "Transition must be unique")
	_transitions[key] = to


func setup_state_nodes(config: Dictionary) -> void:
	for state in _nodes.values():
		state.setup(config)


func set_start_state_node(start: String) -> void:
	assert(_nodes.has(start), "Can't set nonexising node as a start node")
	_current_state = _nodes[start]


func input(input: String) -> void:
	var new_state_name = _current_state.name + "/" + input
	if not _transitions.has(new_state_name):
		return

	if new_state_name != _current_state.name:
		_current_state.state_exit()
		_current_state = _nodes[_transitions[new_state_name]]
		_current_state.state_enter()


func _on_input(input: String) -> void:
	input(input)


func _ready() -> void:
	if not Engine.is_editor_hint():
		_current_state.state_enter()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_current_state.state_process(delta)


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_current_state.state_physics_process(delta)


func get_transitions() -> Dictionary:
	return _transitions
