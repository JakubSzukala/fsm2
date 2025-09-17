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

	view_dock.get_node("Button").text = fsm.as_view()["dwight"]


func _handles(object: Object) -> bool:
	return object is FSM2Base


func _make_visible(visible: bool) -> void:
	view_dock_button.visible = visible


func _exit_tree() -> void:
	remove_custom_type("FSM2Base")

	remove_control_from_bottom_panel(view_dock)
	view_dock.free()
