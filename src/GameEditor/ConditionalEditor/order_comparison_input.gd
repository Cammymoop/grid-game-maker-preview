extends OptionButton

var arg_name: String = ""

var all_items: Array[String] = []

var conversions: Dictionary[String, String] = {
	">=": "≥",
	"<=": "≤",
	"!=": "≠",
}
var reverse_conversions: Dictionary[String, String] = {}

func _init() -> void:
	all_items = []
	for i in get_item_count():
		all_items.append(get_item_text(i))
	
	for key in conversions:
		reverse_conversions[conversions[key]] = key

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func get_value() -> String:
	var raw_val = get_item_text(selected)
	if raw_val in reverse_conversions:
		return reverse_conversions[raw_val]
	return raw_val

func set_value(new_val: String) -> void:
	if new_val == "==":
		new_val = "="
	if new_val in conversions:
		new_val = conversions[new_val]
	var index = all_items.find(new_val)
	if index == -1:
		index = 0
	select(index)

