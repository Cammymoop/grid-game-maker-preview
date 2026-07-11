extends Node

# Really simple whitelisted expression builder to make godot expressions in a way that avoids arbitrary code execution exploits from unknown data

var expression_cache: Dictionary[StringName, Dictionary] = {}

const BASIC_EXPR_MAX_LIST_LITERAL: int = 1000

const EMPTY_STRING_OUTPUT: String = ' ""'

const ALLOWED_ASCII_RANGES: Array[Array] = [
    [0x30, 0x3A], # 0-9
    [0x41, 0x5B], # A-Z
    [0x61, 0x7B], # a-z
    [0x20, 0x21], # space
    [0x2D, 0x2E], # dash
    [0x5F, 0x60], # underscore
]

const GGM_EXPR_TYPES: Array[String] = [
    "basic_expr",
]

const OPERATORS: Array[String] = [
    ">", "<", "==", "!=", ">=", "<=",
    "+", "-", "*", "**", "/", "%",
    "&&", "||",
    "in", "and", "or",
    
    "&", "|", "^", "<<", ">>",
]

const UNARY_OPERATORS: Array[String] = [
    "not", "~"
]

const CONSTANTS: Array[String] = [
    "PI", "TAU", "INF", "NAN", "null",
]

const UNARY_FUNCTIONS: Array[String] = [
    "abs", "acos", "asin", "atan", "ceil", "cos", "deg_to_rad", "exp", "floor", "is_finite", "is_nan", "is_zero_approx", "log",
    "nearest_po2", "rad_to_deg", "round", "roundf", "roundi", "sign", "sin", "sqrt", "tan",
    
    "typeof",

    "str", "int", "float",
]

const TWO_ARG_FUNCTIONS: Array[String] = [
    "angle_difference", "atan2", "ease", "fmod", "fposmod", "is_equal_approx", "max", "maxf", "maxi", "min", "minf", "mini",
    "pingpong", "posmod", "pow", "snapped", "snappedf", "snappedi",

    "type_convert",
]

const THREE_ARG_FUNCTIONS: Array[String] = [
    "clamp", "clampf", "clampi", "inverse_lerp", "lerp", "lerp_angle", "lerpf", "max", "min", "move_toward", "rotate_toward",
    "smoothstep", "wrap", "wrapf", "wrapi",
]


func get_safe_godot_expression_string(unsafe_expr_string: StringName, variable_names: Array = []) -> String:
    if unsafe_expr_string in expression_cache:
        return _make_godot_expression(expression_cache[unsafe_expr_string])
    
    var parsed_expr_data: Variant = _expression_data_from_string(unsafe_expr_string)
    if not parsed_expr_data or typeof(parsed_expr_data) != TYPE_DICTIONARY:
        return ""
    
    var vnames: Array[String] = []
    vnames.assign(variable_names)
    
    var built_expression: Dictionary = _build_expression(parsed_expr_data, vnames)
    if not built_expression:
        return ""
    expression_cache[unsafe_expr_string] = built_expression
    return _make_godot_expression(built_expression)


func make_expression_data_str(unsafe_expr_data: Dictionary) -> String:
    return JSON.stringify(unsafe_expr_data)

func _expression_data_from_string(unsafe_expr_string: StringName) -> Dictionary:
    var parsed_expr_data: Variant = JSON.parse_string(unsafe_expr_string)
    if typeof(parsed_expr_data) != TYPE_DICTIONARY:
        return {}
    return parsed_expr_data

func _make_godot_expression(expression_data: Dictionary) -> String:
    if not expression_data.has("ggm-safe-expr"):
        return ""
    return _dict_get_string(expression_data, "godot-expr-string")

func _validate_expr_data(unsafe_expr_data: Dictionary) -> bool:
    if not unsafe_expr_data.has("ggm-expr") or typeof(unsafe_expr_data["ggm-expr"]) != TYPE_STRING:
        return false
    if not unsafe_expr_data.has("ggm-expr-version") or typeof(unsafe_expr_data["ggm-expr-version"]) != TYPE_FLOAT:
        return false
    if unsafe_expr_data["ggm-expr"] not in GGM_EXPR_TYPES:
        return false
    return true

func _build_expression(unsafe_expr_data: Dictionary, variable_names: Array[String] = []) -> Dictionary:
    if not _validate_expr_data(unsafe_expr_data):
        return {}
    var expr_type: String = unsafe_expr_data["ggm-expr"]
    if expr_type == "basic_expr":
        return _build_basic_expression(unsafe_expr_data, variable_names)
    else:
        push_error("Expression type %s not implemented" % expr_type)
    
    return {}

func _build_basic_expression(expr: Dictionary, variable_names: Array[String] = []) -> Dictionary:
    var expression_tree: Dictionary = _dict_get_dict(expr, "expression_tree")
    var ggm_expression: Dictionary = {
        "ggm-safe-expr": 1,
        "godot-expr-string": "",
    }
    var built_expression: String = _basic_expression_build_recursive(expression_tree, variable_names)
    built_expression = built_expression.strip_edges()
    if not built_expression:
        return {}
    if built_expression.begins_with("(") and built_expression.ends_with(")"):
        built_expression = built_expression.substr(1, built_expression.length() - 2)
    ggm_expression["godot-expr-string"] = built_expression
    return ggm_expression

func _basic_expression_build_recursive(sub_expression: Dictionary, vars: Array[String] = []) -> String:
    if not sub_expression:
        return ""
    var node_type: = _dict_get_string(sub_expression, "node")
    if not node_type:
        return ""

    if node_type == "decimal":
        var float_value: = _dict_get_float(sub_expression, "value")
        if is_finite(float_value):
            return str(float_value)
        elif is_nan(float_value):
            return "NAN"
        elif is_inf(float_value):
            return "INF"
        else:
            return ""
    elif node_type == "integer":
        return str(_dict_get_int(sub_expression, "value"))
    elif node_type == "bool":
        return str(_dict_get_bool(sub_expression, "value"))
    elif node_type == "string":
        if _dict_is_empty_string(sub_expression, "value"):
            return EMPTY_STRING_OUTPUT
        var string_value: = get_restricted_string(_dict_get_string(sub_expression, "value"))
        if not string_value:
            return ""
        return ' "' + string_value + '"'
    elif node_type == "constant":
        var constant_name: = _dict_get_string(sub_expression, "name")
        if constant_name in CONSTANTS:
            return constant_name
        return ""
    elif node_type == "empty_list":
        return " []"
    elif node_type == "operation":
        var operator: = _dict_get_string(sub_expression, "op")
        if operator in OPERATORS:
            var left_operand: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "left"), vars)
            var right_operand: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "right"), vars)
            if left_operand and right_operand:
                return " (" + left_operand + " " + operator + " " + right_operand + ")"
        return ""
    elif node_type == "unary_op":
        var operator: = _dict_get_string(sub_expression, "op")
        if operator in UNARY_OPERATORS:
            var operand: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "operand"), vars)
            if operand:
                return " (" + operator + " " + operand + ")"
        return ""
    elif node_type == "variable":
        var variable_name: = _dict_get_string(sub_expression, "name")
        if not variable_name.is_valid_ascii_identifier() or variable_name not in vars:
            return ""
        return variable_name
    elif node_type == "unary_func":
        var function_name: = _dict_get_string(sub_expression, "name")
        if function_name in UNARY_FUNCTIONS:
            var arg: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg"), vars)
            if arg:
                return function_name + "(" + arg + ")"
        return ""
    elif node_type == "two_func":
        var function_name: = _dict_get_string(sub_expression, "name")
        if function_name in TWO_ARG_FUNCTIONS:
            var arg1: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg1"), vars)
            var arg2: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg2"), vars)
            if arg1 and arg2:
                return function_name + "(" + arg1 + ", " + arg2 + ")"
        return ""
    elif node_type == "three_func":
        var function_name: = _dict_get_string(sub_expression, "name")
        if function_name in THREE_ARG_FUNCTIONS:
            var arg1: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg1"), vars)
            var arg2: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg2"), vars)
            var arg3: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg3"), vars)
            if arg1 and arg2 and arg3:
                return function_name + "(" + arg1 + ", " + arg2 + ", " + arg3 + ")"
        return ""
    elif node_type == "list":
        var list_items: Array = _dict_get_array(sub_expression, "items")
        if not list_items or list_items.size() > BASIC_EXPR_MAX_LIST_LITERAL:
            return ""

        var list_items_built: Array[String] = []
        for item in list_items:
            if typeof(item) != TYPE_DICTIONARY:
                return ""

            var item_built: String = _basic_expression_build_recursive(item, vars)
            if not item_built:
                return ""
            list_items_built.append(item_built)
        return " [" + ", ".join(list_items_built) + "]"
    return ""


func e_wrap(expr: Dictionary) -> Dictionary:
    return {
        "ggm-expr": "basic_expr",
        "ggm-expr-version": 1,
        "expression_tree": expr,
    }

func e_val(literal_value: Variant) -> Dictionary:
    if typeof(literal_value) == TYPE_NIL or (typeof(literal_value) == TYPE_OBJECT and literal_value == null):
        return e_null()
    if typeof(literal_value) == TYPE_FLOAT:
        if is_finite(literal_value):
            return { "node": "decimal", "value": literal_value, }
        elif is_nan(literal_value):
            return e_const("NAN")
        else:
            return e_const("INF")
    elif typeof(literal_value) == TYPE_INT:
        return { "node": "integer", "value": literal_value, }
    elif typeof(literal_value) == TYPE_BOOL:
        return { "node": "bool", "value": literal_value, }
    elif typeof(literal_value) == TYPE_STRING:
        return e_string(literal_value)
    else:
        push_error("Unsupported value type: %s" % [type_string(typeof(literal_value))])
        return {}

func e_var(var_name: String) -> Dictionary:
    return { "node": "variable", "name": var_name, }

func e_const(constant_name: String) -> Dictionary:
    if constant_name not in CONSTANTS:
        push_error("Invalid constant name: %s" % constant_name)
        return {}
    return { "node": "constant", "name": constant_name, }

func e_null() -> Dictionary:
    return e_const("null")

func e_not(sub_expr: Dictionary) -> Dictionary:
    return { "node": "unary_op", "op": "not", "operand": sub_expr, }

func e_bit_not(sub_expr: Dictionary) -> Dictionary:
    return { "node": "unary_op", "op": "~", "operand": sub_expr, }

func e_op(left_expr: Dictionary, op: String, right_expr: Dictionary) -> Dictionary:
    if op not in OPERATORS:
        push_error("Invalid operator: %s" % op)
        return {}
    return { "node": "operation", "op": op, "left": left_expr, "right": right_expr, }

func e_func1(func_name: String, arg: Dictionary) -> Dictionary:
    if func_name not in UNARY_FUNCTIONS:
        push_error("Invalid unary function name: %s" % func_name)
        return {}
    return { "node": "unary_func", "name": func_name, "arg": arg, }

func e_func2(func_name: String, arg1: Dictionary, arg2: Dictionary) -> Dictionary:
    if func_name not in TWO_ARG_FUNCTIONS:
        push_error("Invalid two-argument function name: %s" % func_name)
        return {}
    return { "node": "two_func", "name": func_name, "arg1": arg1, "arg2": arg2, }

func e_func3(func_name: String, arg1: Dictionary, arg2: Dictionary, arg3: Dictionary) -> Dictionary:
    if func_name not in THREE_ARG_FUNCTIONS:
        push_error("Invalid three-argument function name: %s" % func_name)
        return {}
    return { "node": "three_func", "name": func_name, "arg1": arg1, "arg2": arg2, "arg3": arg3, }

func e_empty_list() -> Dictionary:
    return { "node": "empty_list", }

func e_list(...args: Array) -> Dictionary:
    return e_listv(args)

func e_listv(items: Array) -> Dictionary:
    if not items or items.size() > BASIC_EXPR_MAX_LIST_LITERAL:
        push_error("List size exceeds maximum allowed: %s" % items.size())
        return {}
    if items.size() == 0:
        return e_empty_list()
    return { "node": "list", "items": items, }

func e_raw_list(...args: Array) -> Dictionary:
    return e_raw_listv(args)

func e_raw_listv(items: Array) -> Dictionary:
    if not items or items.size() > BASIC_EXPR_MAX_LIST_LITERAL:
        push_error("List size exceeds maximum allowed: %s" % items.size())
        return {}
    if items.size() == 0:
        return e_empty_list()
    var converted_items: Array[Dictionary] = []
    for raw_item in items:
        converted_items.append(e_val(raw_item))
    return { "node": "list", "items": converted_items, }

func e_string(string_value: String) -> Dictionary:
    if not string_value:
        return { "node": "string", "value": "", }
    var restricted_string: String = get_restricted_string(string_value)
    if not restricted_string:
        push_error("String contains non-allowed characters (alphanumeric, space, dash, underscore only): %s" % string_value)
        return {}
    return { "node": "string", "value": restricted_string, }


func get_restricted_string(raw_string: String) -> String:
    var restricted_string: String = ""
    for single_char in raw_string:
        var code_point: int = ord(single_char)
        if code_point > 0x7F: # non-ascii
            return ""
        var allowed: bool = false
        for allowed_range in ALLOWED_ASCII_RANGES:
            if code_point >= allowed_range[0] and code_point < allowed_range[1]:
                allowed = true
                break
        if not allowed:
            return ""
        restricted_string += single_char
    return restricted_string



func _dict_get_dict(dict: Dictionary, key: String) -> Dictionary:
    if not dict.has(key) or typeof(dict[key]) != TYPE_DICTIONARY:
        return {}
    return dict[key]

func _dict_get_array(dict: Dictionary, key: String) -> Array:
    if not dict.has(key) or typeof(dict[key]) != TYPE_ARRAY:
        return []
    return dict[key]

func _dict_is_empty_string(dict: Dictionary, key: String) -> bool:
    if not dict.has(key) or typeof(dict[key]) != TYPE_STRING:
        return false
    return dict[key] == ""

func _dict_get_string(dict: Dictionary, key: String) -> String:
    if not dict.has(key) or typeof(dict[key]) != TYPE_STRING:
        return ""
    return dict[key]

func _dict_get_float(dict: Dictionary, key: String) -> float:
    if not dict.has(key) or (typeof(dict[key]) != TYPE_FLOAT and typeof(dict[key]) != TYPE_INT):
        return 0.0
    return float(dict[key])

func _dict_get_int(dict: Dictionary, key: String) -> int:
    if not dict.has(key) or (typeof(dict[key]) != TYPE_FLOAT and typeof(dict[key]) != TYPE_INT):
        return 0
    return int(dict[key])

func _dict_get_bool(dict: Dictionary, key: String) -> bool:
    if not dict.has(key) or typeof(dict[key]) != TYPE_BOOL:
        return false
    return dict[key]