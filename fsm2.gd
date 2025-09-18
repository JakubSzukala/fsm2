@tool
extends EditorPlugin

var view_dock: FSM2View
var view_dock_button: Button


func _enter_tree() -> void:
	add_custom_type("FSM2Base", "Node", preload("res://addons/fsm2/fsm2_base.gd"), preload("res://icon.svg"))

	view_dock = preload("res://addons/fsm2/fsm2_view.tscn").instantiate()
	view_dock_button = add_control_to_bottom_panel(view_dock, "FSM2")


func _edit(object: Object) -> void:
	var fsm = object as FSM2Base
	if not fsm:
		return

	var transitions = fsm.get_transitions() as Dictionary
	var transitions_view = {}
	for from_and_on: String in transitions.keys():
		# Convert from inference form into view-friendly form
		var from: String = from_and_on.split("/")[0]
		var on: String = from_and_on.split("/")[1]
		var to: String = transitions[from_and_on]
		if not transitions_view.has(from):
			transitions_view[from] = []
		transitions_view[from].append({"on" : on, "to" : to})
	view_dock.visualize(transitions_view)


func _handles(object: Object) -> bool:
	return object is FSM2Base


func _make_visible(visible: bool) -> void:
	view_dock_button.visible = visible


func _exit_tree() -> void:
	remove_custom_type("FSM2Base")

	remove_control_from_bottom_panel(view_dock)
	view_dock.free()
