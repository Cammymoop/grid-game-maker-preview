extends Node

const OVERLAY_SCRIPT := preload("res://src/Autocomplete/autocomplete_overlay.gd")

## Host Node (Window or root) -> overlay Control (AutocompleteOverlay)
var _overlays_by_host: Dictionary = {}
var _session_anchor: Control
var _session_list: Panel


func acquire_menu(anchor: Control) -> Panel:
	var host := _resolve_host(anchor)
	var overlay: Control = _ensure_overlay_for_host(host)
	return overlay.acquire_menu(anchor)


func get_active_list() -> Panel:
	for host in _overlays_by_host:
		var overlay: Control = _overlays_by_host[host]
		if not is_instance_valid(overlay):
			continue
		var lst: Panel = overlay.get_active_list()
		if lst != null and lst.visible:
			return lst
	return null


func begin_outside_click_watch(list: Panel) -> void:
	_session_list = list
	_session_anchor = list.get_anchor_control()
	set_process_input(true)


func end_outside_click_watch() -> void:
	_session_list = null
	_session_anchor = null
	set_process_input(false)


func _resolve_host(anchor: Control) -> Node:
	var w := anchor.get_window()
	if w != null:
		return w
	return get_tree().root


func _ensure_overlay_for_host(host: Node) -> Control:
	if _overlays_by_host.has(host):
		var existing: Control = _overlays_by_host[host]
		if is_instance_valid(existing):
			return existing
		_overlays_by_host.erase(host)
	var canvas := CanvasLayer.new()
	canvas.name = &"AutocompleteHostCanvas"
	canvas.layer = 200
	var overlay: Control = OVERLAY_SCRIPT.new()
	canvas.add_child(overlay)
	host.add_child(canvas)
	canvas.tree_exited.connect(_on_autocomplete_canvas_exited.bind(host))
	_overlays_by_host[host] = overlay
	return overlay


func _on_autocomplete_canvas_exited(host: Node) -> void:
	_overlays_by_host.erase(host)


func _input(event: InputEvent) -> void:
	if _session_list == null or not is_instance_valid(_session_list) or not _session_list.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	var gp := mb.global_position
	if is_instance_valid(_session_anchor) and _session_anchor.get_global_rect().has_point(gp):
		return
	if _session_list.get_global_rect().has_point(gp):
		return
	_session_list.dismiss_external()
	get_viewport().set_input_as_handled()
